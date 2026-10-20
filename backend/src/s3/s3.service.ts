import {
  GetObjectCommand,
  HeadObjectCommand,
  ListObjectsV2Command,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'node:crypto';

export interface DocumentItem {
  key: string;
  name: string;
  size: number;
  lastModified: string | null;
}

// Quita el prefijo UUID para mostrar el nombre original
export function displayName(key: string): string {
  return key.replace(/^[0-9a-f-]{36}-/, '');
}

const UPLOAD_URL_TTL_SECONDS = 300; // 5 min para iniciar la subida
const VIEW_URL_TTL_SECONDS = 900; // 15 min, según el enunciado

@Injectable()
export class S3Service {
  private readonly client: S3Client;
  private readonly bucket: string;

  constructor(config: ConfigService) {
    // getOrThrow: si falta la variable, la app falla al arrancar
    const region = config.getOrThrow<string>('AWS_REGION');
    this.bucket = config.getOrThrow<string>('S3_BUCKET_NAME');

    // SIN credenciales: el SDK usa la cadena por defecto.
    //  - En EC2: credenciales temporales del Instance Profile vía IMDSv2.
    //  - En local: las de `aws configure` (perfil o variables de entorno).
    this.client = new S3Client({
      region,
      // Las versiones recientes del SDK agregan un checksum CRC32 a las URLs firmadas
      // de PutObject, y el PUT directo desde el navegador falla. Con WHEN_REQUIRED no se agrega.
      requestChecksumCalculation: 'WHEN_REQUIRED',
    });
  }

  async listDocuments(): Promise<DocumentItem[]> {
    const items: DocumentItem[] = [];
    let continuationToken: string | undefined;

    do {
      const res = await this.client.send(
        new ListObjectsV2Command({
          Bucket: this.bucket,
          ContinuationToken: continuationToken,
        }),
      );

      for (const obj of res.Contents ?? []) {
        if (!obj.Key) continue;
        items.push({
          key: obj.Key,
          name: displayName(obj.Key),
          size: obj.Size ?? 0,
          lastModified: obj.LastModified?.toISOString() ?? null,
        });
      }

      continuationToken = res.NextContinuationToken;
    } while (continuationToken);

    return items.sort((a, b) =>
      (b.lastModified ?? '').localeCompare(a.lastModified ?? ''),
    );
  }

  // Pregunta a S3 por los metadatos reales de un objeto. Devuelve null si no existe.
  async headObject(
    key: string,
  ): Promise<{ size: number; contentType: string | null } | null> {
    try {
      const res = await this.client.send(
        new HeadObjectCommand({ Bucket: this.bucket, Key: key }),
      );
      return {
        size: res.ContentLength ?? 0,
        contentType: res.ContentType ?? null,
      };
    } catch (err) {
      const status = (err as { $metadata?: { httpStatusCode?: number } })
        .$metadata?.httpStatusCode;
      if (status === 404) return null;
      throw err;
    }
  }

  async createUploadUrl(filename: string, fileType: string) {
    const key = `${randomUUID()}-${this.sanitizeFilename(filename)}`;

    const command = new PutObjectCommand({
      Bucket: this.bucket,
      Key: key,
      // El Content-Type queda firmado: el navegador debe enviar exactamente el mismo
      ContentType: fileType,
    });

    const url = await getSignedUrl(this.client, command, {
      expiresIn: UPLOAD_URL_TTL_SECONDS,
    });

    return { url, key, expiresIn: UPLOAD_URL_TTL_SECONDS };
  }

  async createViewUrl(key: string) {
    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: key,
    });

    const url = await getSignedUrl(this.client, command, {
      expiresIn: VIEW_URL_TTL_SECONDS,
    });

    return { url, expiresIn: VIEW_URL_TTL_SECONDS };
  }

  // Deja solo caracteres seguros; slice(-100) conserva la extensión al final
  private sanitizeFilename(filename: string): string {
    const clean = filename
      .normalize('NFKD')
      .replace(/[^\w.-]/g, '_')
      .replace(/_+/g, '_')
      .replace(/^[._]+/, '')
      .slice(-100);

    return clean || 'file';
  }
}

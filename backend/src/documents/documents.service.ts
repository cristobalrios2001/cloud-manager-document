import { Injectable, NotFoundException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { displayName, S3Service, type DocumentItem } from '../s3/s3.service';

interface DocumentRow {
  key: string;
  name: string;
  size_bytes: string; // pg devuelve BIGINT como string
  uploaded_at: Date;
}

@Injectable()
export class DocumentsService {
  constructor(
    private readonly s3: S3Service,
    private readonly db: DatabaseService,
  ) {}

  // Con base de datos lee de PostgreSQL; sin ella (fase F1) lista el bucket
  async list(): Promise<DocumentItem[]> {
    if (!this.db.enabled) return this.s3.listDocuments();

    const { rows } = await this.db.query<DocumentRow>(
      `SELECT key, name, size_bytes, uploaded_at
         FROM documents
        ORDER BY uploaded_at DESC
        LIMIT 500`,
    );

    return rows.map((r) => ({
      key: r.key,
      name: r.name,
      size: Number(r.size_bytes),
      lastModified: r.uploaded_at.toISOString(),
    }));
  }

  // El navegador avisa que terminó el PUT. El backend NO confía en lo que diga el cliente:
  // pregunta a S3 por el tamaño y el tipo reales antes de guardar los metadatos.
  async confirmUpload(key: string): Promise<{ stored: boolean }> {
    const head = await this.s3.headObject(key);
    if (!head) throw new NotFoundException('El archivo no existe en S3');

    if (!this.db.enabled) return { stored: false };

    // ON CONFLICT: confirmar dos veces (o un reintento tras un corte) no duplica la fila
    await this.db.query(
      `INSERT INTO documents (key, name, content_type, size_bytes)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (key) DO NOTHING`,
      [key, displayName(key), head.contentType, head.size],
    );

    return { stored: true };
  }
}

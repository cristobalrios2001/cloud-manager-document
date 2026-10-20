import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Pool, type QueryResult, type QueryResultRow } from 'pg';

// Clave arbitraria del advisory lock: evita que dos instancias creen la tabla a la vez
const SCHEMA_LOCK_ID = 727_274;

const SCHEMA_SQL = `
  CREATE TABLE IF NOT EXISTS documents (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    key          TEXT        NOT NULL UNIQUE,
    name         TEXT        NOT NULL,
    content_type TEXT,
    size_bytes   BIGINT      NOT NULL DEFAULT 0,
    uploaded_at  TIMESTAMPTZ NOT NULL DEFAULT now()
  )
`;

const STARTUP_ATTEMPTS = 10;
const STARTUP_DELAY_MS = 3_000;
const QUERY_ATTEMPTS = 4;

// Errores de conexión (típicos durante un failover de RDS): vale la pena reintentar
const RETRYABLE_CODES = new Set([
  'ECONNRESET',
  'ECONNREFUSED',
  'ETIMEDOUT',
  'EPIPE',
  '57P01', // admin_shutdown
  '57P02', // crash_shutdown
  '57P03', // cannot_connect_now
  '08000',
  '08001',
  '08003',
  '08006',
]);

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DatabaseService.name);
  private pool?: Pool;

  // La base es opcional: sin DB_HOST la app sigue funcionando solo con S3 (fase F1)
  readonly enabled: boolean;

  constructor(private readonly config: ConfigService) {
    this.enabled = !!this.config.get<string>('DB_HOST');
  }

  async onModuleInit() {
    if (!this.enabled) {
      this.logger.warn('DB_HOST vacío: la base de datos está desactivada.');
      return;
    }

    // RDS PostgreSQL 15+ exige SSL. En local (docker compose) usa DB_SSL=false.
    // rejectUnauthorized:false cifra pero no valida el certificado: aceptable en el laboratorio;
    // en producción instala el bundle de CA de RDS y valídalo.
    const useSsl = this.config.get<string>('DB_SSL', 'true') !== 'false';

    this.pool = new Pool({
      host: this.config.get<string>('DB_HOST'),
      port: Number(this.config.get<string>('DB_PORT', '5432')),
      database: this.config.get<string>('DB_NAME', 'documents'),
      user: this.config.get<string>('DB_USER'),
      password: this.config.get<string>('DB_PASSWORD'),
      ssl: useSsl ? { rejectUnauthorized: false } : false,
      max: 5,
      connectionTimeoutMillis: 5_000,
      idleTimeoutMillis: 30_000,
      keepAlive: true,
    });

    // Sin este handler, un error en una conexión ociosa (p. ej. al conmutar Multi-AZ)
    // tumbaría todo el proceso de Node.
    this.pool.on('error', (err) => {
      this.logger.error(`Error en una conexión ociosa: ${err.message}`);
    });

    await this.initSchema();
  }

  async onModuleDestroy() {
    await this.pool?.end();
  }

  // Crea la tabla si falta. Reintenta porque la base puede estar terminando de arrancar.
  private async initSchema() {
    for (let attempt = 1; attempt <= STARTUP_ATTEMPTS; attempt++) {
      try {
        // Una réplica de lectura (región 2) es de solo lectura: el esquema ya viene replicado
        const { rows } = await this.pool!.query<{ replica: boolean }>(
          'SELECT pg_is_in_recovery() AS replica',
        );
        if (rows[0]?.replica) {
          this.logger.warn(
            'La base es una réplica de solo lectura: se omite el esquema.',
          );
          return;
        }

        const client = await this.pool!.connect();
        try {
          await client.query('SELECT pg_advisory_lock($1)', [SCHEMA_LOCK_ID]);
          await client.query(SCHEMA_SQL);
        } finally {
          await client
            .query('SELECT pg_advisory_unlock($1)', [SCHEMA_LOCK_ID])
            .catch(() => undefined);
          client.release();
        }

        this.logger.log('Base de datos lista (tabla documents verificada).');
        return;
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        if (attempt === STARTUP_ATTEMPTS) throw err;
        this.logger.warn(
          `Base no disponible (intento ${attempt}/${STARTUP_ATTEMPTS}): ${message}`,
        );
        await sleep(STARTUP_DELAY_MS);
      }
    }
  }

  async query<T extends QueryResultRow = QueryResultRow>(
    text: string,
    params: unknown[] = [],
  ): Promise<QueryResult<T>> {
    if (!this.pool) {
      throw new ServiceUnavailableException(
        'La base de datos no está configurada',
      );
    }

    for (let attempt = 1; ; attempt++) {
      try {
        return await this.pool.query<T>(text, params);
      } catch (err) {
        if (attempt >= QUERY_ATTEMPTS || !this.isRetryable(err)) throw err;
        this.logger.warn(
          `Consulta fallida, reintento ${attempt}/${QUERY_ATTEMPTS - 1}`,
        );
        await sleep(attempt * 1_000);
      }
    }
  }

  async ping(): Promise<void> {
    await this.query('SELECT 1');
  }

  private isRetryable(err: unknown): boolean {
    if (!(err instanceof Error)) return false;
    const code = (err as { code?: string }).code;
    if (code && RETRYABLE_CODES.has(code)) return true;
    return /terminated|timeout|ECONN/i.test(err.message);
  }
}

import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { DatabaseModule } from './database/database.module';
import { DocumentsModule } from './documents/documents.module';
import { HealthModule } from './health/health.module';
import { S3Module } from './s3/s3.module';

@Module({
  imports: [
    // Lee variables de entorno (y .env en desarrollo local)
    ConfigModule.forRoot({ isGlobal: true }),
    DatabaseModule,
    S3Module,
    HealthModule,
    DocumentsModule,
  ],
})
export class AppModule {}

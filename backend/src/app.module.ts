import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { DocumentsModule } from './documents/documents.module';
import { S3Module } from './s3/s3.module';

@Module({
  imports: [
    // Lee variables de entorno (y .env en desarrollo local)
    ConfigModule.forRoot({ isGlobal: true }),
    S3Module,
    DocumentsModule,
  ],
})
export class AppModule {}
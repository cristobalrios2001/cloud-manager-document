import { Module } from '@nestjs/common';
import { S3Module } from '../s3/s3.module';
import { DocumentsController } from './documents.controller';

@Module({
  imports: [S3Module],
  controllers: [DocumentsController],
})
export class DocumentsModule {}
import { Module } from '@nestjs/common';
import { S3Module } from '../s3/s3.module';
import { DocumentsController } from './documents.controller';
import { DocumentsService } from './documents.service';

@Module({
  imports: [S3Module],
  controllers: [DocumentsController],
  providers: [DocumentsService],
})
export class DocumentsModule {}

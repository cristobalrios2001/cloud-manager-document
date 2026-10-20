import { Body, Controller, Get, HttpCode, Post } from '@nestjs/common';
import { S3Service } from '../s3/s3.service';
import { DocumentsService } from './documents.service';
import { ConfirmUploadDto } from './dto/confirm-upload.dto';
import { UploadUrlDto } from './dto/upload-url.dto';
import { ViewUrlDto } from './dto/view-url.dto';

@Controller('documents')
export class DocumentsController {
  constructor(
    private readonly s3: S3Service,
    private readonly documents: DocumentsService,
  ) {}

  // GET /api/documents -> lista los documentos (PostgreSQL si está activa; si no, el bucket)
  @Get()
  list() {
    return this.documents.list();
  }

  // POST /api/documents/upload-url { filename, fileType } -> URL firmada para PUT
  @Post('upload-url')
  @HttpCode(200)
  uploadUrl(@Body() dto: UploadUrlDto) {
    return this.s3.createUploadUrl(dto.filename, dto.fileType);
  }

  // POST /api/documents/confirm { key } -> el navegador terminó el PUT; se registran los metadatos
  @Post('confirm')
  @HttpCode(200)
  confirm(@Body() dto: ConfirmUploadDto) {
    return this.documents.confirmUpload(dto.key);
  }

  // POST /api/documents/view-url { key } -> URL firmada para GET (15 min)
  @Post('view-url')
  @HttpCode(200)
  viewUrl(@Body() dto: ViewUrlDto) {
    return this.s3.createViewUrl(dto.key);
  }
}

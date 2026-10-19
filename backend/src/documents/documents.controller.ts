import { Body, Controller, Get, HttpCode, Post } from '@nestjs/common';
import { S3Service } from '../s3/s3.service';
import { UploadUrlDto } from './dto/upload-url.dto';
import { ViewUrlDto } from './dto/view-url.dto';

@Controller('documents')
export class DocumentsController {
  constructor(private readonly s3: S3Service) {}

  // GET /documents -> lista los archivos del bucket
  @Get()
  list() {
    return this.s3.listDocuments();
  }

  // POST /documents/upload-url { filename, fileType } -> URL firmada para PUT
  @Post('upload-url')
  @HttpCode(200)
  uploadUrl(@Body() dto: UploadUrlDto) {
    return this.s3.createUploadUrl(dto.filename, dto.fileType);
  }

  // POST /documents/view-url { key } -> URL firmada para GET (15 min)
  @Post('view-url')
  @HttpCode(200)
  viewUrl(@Body() dto: ViewUrlDto) {
    return this.s3.createViewUrl(dto.key);
  }
}
import { IsNotEmpty, IsString, Matches, MaxLength } from 'class-validator';

export class UploadUrlDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(255)
  filename!: string;

  @IsString()
  @Matches(/^[\w.+-]+\/[\w.+-]+$/, {
    message: 'fileType debe ser un MIME type válido (ej: application/pdf)',
  })
  fileType!: string;
}
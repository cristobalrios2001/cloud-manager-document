import { IsString, Matches, MaxLength } from 'class-validator';

export class ConfirmUploadDto {
  // Formato que genera el backend: <uuid>-<nombre>. Rechaza cualquier otra cosa.
  @IsString()
  @MaxLength(1024)
  @Matches(
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}-.+$/,
    {
      message: 'key no tiene el formato generado por upload-url',
    },
  )
  key!: string;
}

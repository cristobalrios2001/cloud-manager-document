import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class ViewUrlDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(1024)
  key!: string;
}
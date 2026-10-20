import { Global, Module } from '@nestjs/common';
import { DatabaseService } from './database.service';

// @Global: cualquier módulo puede inyectar DatabaseService sin importar este módulo
@Global()
@Module({
  providers: [DatabaseService],
  exports: [DatabaseService],
})
export class DatabaseModule {}
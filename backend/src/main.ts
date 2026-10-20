import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Todas las rutas quedan bajo /api (ej: /api/health, /api/documents).
  // El ALB envía /api/* al backend, y el resto de las rutas al frontend.
  app.setGlobalPrefix('api');

  // Valida los DTOs y rechaza campos que no estén declarados
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // Con el ALB el navegador llama a /api en el mismo origen, así que CORS ya no es necesario
  // para el tráfico normal. Se deja abierto para el desarrollo local; en producción restringe `origin`.
  app.enableCors();

  app.enableShutdownHooks();

  const port = Number(process.env.PORT ?? 4000);
  await app.listen(port, '0.0.0.0');
}

void bootstrap();

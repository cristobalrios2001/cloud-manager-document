import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Controller('health')
export class HealthController {
  constructor(private readonly db: DatabaseService) {}

  // GET /api/health -> lo consulta el ALB cada 30 s.
  // A PROPOSITO no toca la base: si la base cae unos segundos (failover), el ALB no debe marcar
  // todas las instancias como unhealthy, porque el Auto Scaling Group las terminaría a todas.
  @Get()
  live() {
    return { status: 'ok' };
  }

  // GET /api/health/ready -> para que TU compruebes la conexión a la base (no lo usa el ALB)
  @Get('ready')
  async ready() {
    if (!this.db.enabled) return { status: 'ok', database: 'disabled' };

    try {
      await this.db.ping();
      return { status: 'ok', database: 'up' };
    } catch {
      throw new ServiceUnavailableException({
        status: 'degraded',
        database: 'down',
      });
    }
  }
}

# REGION 2 (F4): copia de los datos + pila minima en espera ("pilot light")
#
# - S3: bucket destino con replicacion automatica desde el bucket principal
# - RDS: replica de lectura asincrona (se promueve a mano durante el failover)
# - Computo: ASG con 0 instancias y su ALB, que solo existen si region2_instances > 0
#
# SIMPLIFICACION DE LABORATORIO: la region 2 usa la VPC por defecto de esa region
# (si la borraste, recreala con: aws ec2 create-default-vpc --region <region2>).

locals {
  r2     = var.enable_region2 ? 1 : 0
  r2_db  = var.enable_region2 && var.enable_database ? 1 : 0
  r2_app = var.enable_region2 && var.enable_database && var.region2_instances > 0 ? 1 : 0
}

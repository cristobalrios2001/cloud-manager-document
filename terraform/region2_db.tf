# REGION 2 · BASE DE DATOS (RDS)
# Replica de lectura entre regiones. Solo se crea si enable_region2 y enable_database son true.

# ================== Red de la region 2 (VPC por defecto) ==================
data "aws_vpc" "default" {
  count    = local.r2_db
  provider = aws.region2

  default = true
}

data "aws_subnets" "default" {
  count    = local.r2_db
  provider = aws.region2

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}

# ================== RDS: replica de lectura entre regiones ==================
# Una replica de una base cifrada necesita una clave KMS en la region destino (cuesta ~US$1/mes, aprox.)
resource "aws_kms_key" "replica" {
  count    = local.r2_db
  provider = aws.region2

  description             = "${var.project_name} replica RDS"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_security_group" "db2" {
  count    = local.r2_db
  provider = aws.region2

  name        = "${var.project_name}-db2-sg"
  description = "PostgreSQL solo desde las instancias de la region 2"
  vpc_id      = data.aws_vpc.default[0].id
}

resource "aws_db_subnet_group" "replica" {
  count    = local.r2_db
  provider = aws.region2

  name       = "${var.project_name}-db2-subnets"
  subnet_ids = data.aws_subnets.default[0].ids
}

resource "aws_db_instance" "replica" {
  count    = local.r2_db
  provider = aws.region2

  identifier          = "${var.project_name}-db-replica"
  replicate_source_db = aws_db_instance.main[0].arn
  instance_class      = var.db_instance_class

  storage_encrypted = true
  kms_key_id        = aws_kms_key.replica[0].arn

  multi_az               = false
  db_subnet_group_name   = aws_db_subnet_group.replica[0].name
  vpc_security_group_ids = [aws_security_group.db2[0].id]
  publicly_accessible    = false

  backup_retention_period = 1

  # SOLO LABORATORIO
  skip_final_snapshot = true
  apply_immediately   = true
}

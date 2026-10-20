# BASE DE DATOS (F2): RDS PostgreSQL Multi-AZ en subredes privadas
# Todo lleva count = local.db_on: con enable_database = false no se crea nada.
# La clave se genera con Terraform y se guarda en SSM Parameter Store (SecureString);
# las EC2 la leen con su Instance Profile, sin credenciales estaticas.

locals {
  db_on             = var.enable_database ? 1 : 0
  db_password_param = "/${var.project_name}/db/password"
}

resource "random_password" "db" {
  count = local.db_on

  length  = 24
  special = false # evita caracteres que rompan el archivo .env
}

resource "aws_ssm_parameter" "db_password" {
  count = local.db_on

  name  = local.db_password_param
  type  = "SecureString"
  value = random_password.db[0].result
}

resource "aws_db_subnet_group" "main" {
  count = local.db_on

  name       = "${var.project_name}-db-subnets"
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "${var.project_name}-db-subnets" }
}

resource "aws_db_instance" "main" {
  count = local.db_on

  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db[0].result

  multi_az               = var.db_multi_az
  db_subnet_group_name   = aws_db_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  # Backups > 0 son necesarios para poder crear una replica en otra region
  backup_retention_period = 1

  # SOLO LABORATORIO: permiten destruir sin dejar snapshots ni proteccion
  skip_final_snapshot = true
  deletion_protection = false
  apply_immediately   = true
}

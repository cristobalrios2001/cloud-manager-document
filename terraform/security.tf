# FIREWALLS ENCADENADOS: Internet -> ALB -> EC2 -> RDS
# Cada grupo solo acepta trafico del grupo anterior (no de rangos de IP).

# ---------- ALB: unico punto de entrada desde Internet ----------
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Entrada HTTP desde Internet hacia el ALB"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-alb-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP desde Internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_frontend" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB hacia Next.js"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_backend" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB hacia NestJS"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 4000
  to_port                      = 4000
  ip_protocol                  = "tcp"
}

# ---------- EC2: solo acepta trafico del ALB ----------
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Instancias de la aplicacion: solo trafico del ALB"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-app-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "app_frontend" {
  security_group_id            = aws_security_group.app.id
  description                  = "Next.js desde el ALB"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "app_backend" {
  security_group_id            = aws_security_group.app.id
  description                  = "NestJS desde el ALB"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 4000
  to_port                      = 4000
  ip_protocol                  = "tcp"
}

# SSH opcional (solo si defines ssh_cidr). Sin esto entras por SSM Session Manager.
resource "aws_vpc_security_group_ingress_rule" "app_ssh" {
  count = var.ssh_cidr != null ? 1 : 0

  security_group_id = aws_security_group.app.id
  description       = "SSH solo desde tu IP"
  cidr_ipv4         = var.ssh_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_all_out" {
  security_group_id = aws_security_group.app.id
  description       = "Salida libre (descargar paquetes, codigo y hablar con AWS)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------- RDS: solo acepta PostgreSQL desde las EC2 ----------
resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "PostgreSQL solo desde las instancias de la aplicacion"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-db-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "db_postgres" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL desde las EC2"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

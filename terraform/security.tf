# FIREWALL
# ENTRADA: PUERTO 22 (SSH) SOLO DESDE MI IP. PUERTO 3000 (FRONTEND) Y 4000 (API) ABIERTOS PARA PRUEBAS.
# SALIDA: TODO ABIERTO, PARA QUE LA INSTANCIA DESCARGUE PAQUETES, DOCKER, CODIGO, ETC.

resource "aws_security_group" "app" {
  name        = "${var.project_name}-sg"
  description = "Acceso a Next.js (3000), NestJS (4000) y SSH"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.app.id
  description       = "SSH solo desde la IP del desarrollador"
  cidr_ipv4         = var.my_ip
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "frontend" {
  security_group_id = aws_security_group.app.id
  description       = "Next.js"
  cidr_ipv4         = var.allowed_cidr
  from_port         = 3000
  to_port           = 3000
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "backend" {
  security_group_id = aws_security_group.app.id
  description       = "NestJS API"
  cidr_ipv4         = var.allowed_cidr
  from_port         = 4000
  to_port           = 4000
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all_out" {
  security_group_id = aws_security_group.app.id
  description       = "Salida libre a internet"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

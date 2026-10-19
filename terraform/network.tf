# LA RED DONDE VIVE TODO
# UN SERVIDOR AWS NECESITA UNA RED. SE CREAN 5 PIEZAS:
# 1. VPC: RED PRIVADA VIRTUAL EN AWS, AISLADA DE LAS DEMAS
# 2. SUBRED PUBLICA: UNA PORCION DE ESA RED DONDE PONDREMOS LA ec2
# 3. INTERNET GATEWAY (IGW): LA "PUERTA" QUE CONECTA LA VPC CON INTERNET
# 4. TABLA DE RUTAS: DICE "TODO EL TRAFICO HACIA INTERNET (0.0.0.0/0) SALE POR IGW". SIN ESTA RUTA, LA SUBRED NO SERIA REALMENTE PUBLICA.
# 5. ASOCIACIÓN DE LA TABLA A LA SUBRED: CONECTA LA 2 PIEZAS ANTERIORES.

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.project_name}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = { Name = "${var.project_name}-public-subnet" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
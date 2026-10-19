# BUSCA LA IMAGEN MÁS RECIENTE DE AMAZON LINUX (AMI)

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# SUBE LA LLAVE PUBLICA SSH PARA PODER INGRESAR

resource "aws_key_pair" "dev" {
  key_name   = "${var.project_name}-key"
  public_key = file(pathexpand(var.public_key_path))
}

# IP PUBLICA FIJA. SE CREA ANTES QUE LA INSTANCIA PORQUE SE NECESITA CONOCER LA IP PARA EL CORS Y EL FRONTEND
resource "aws_eip" "app" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = { Name = "${var.project_name}-eip" }
}

# SERVIDOR. COMBINA LO ANTERIOR: IMAGEN, TIPO (t3.micro), SUBRED, FIREWALL, INSTANCIA CON ROL IAM, DISCO gp3 DE 20 GB Y user_data

resource "aws_instance" "app" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = aws_key_pair.dev.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true

  # ACTIVA IMDSv2, UNA VERSIÓ MÁS SEGURIA DEL SERVICIO DE CREDENCIALES
  # hop_limit = 2, PERMITE QUE LOS CONTENEDORES DOCKER LO ALMACENEN
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    swap_size_mb = var.swap_size_gb * 1024
    aws_region   = var.aws_region
    bucket_name  = aws_s3_bucket.documents.bucket
    public_ip    = aws_eip.app.public_ip
    repo_url     = var.repo_url
    repo_branch  = var.repo_branch
  })
  user_data_replace_on_change = true

  tags = { Name = "${var.project_name}-ec2" }
}

# UNE LA IP FIJA CON LA INSTANCIA, YA CREADA

resource "aws_eip_association" "app" {
  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.app.id
}

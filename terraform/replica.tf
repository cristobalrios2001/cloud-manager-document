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

# ================== S3: bucket replica ==================
resource "aws_s3_bucket" "replica" {
  count    = local.r2
  provider = aws.region2

  bucket        = "${local.bucket_name}-replica"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "replica" {
  count    = local.r2
  provider = aws.region2

  bucket = aws_s3_bucket.replica[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "replica" {
  count    = local.r2
  provider = aws.region2

  bucket                  = aws_s3_bucket.replica[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "replica" {
  count    = local.r2
  provider = aws.region2

  bucket = aws_s3_bucket.replica[0].id

  rule {
    id     = "expire-test-objects"
    status = "Enabled"

    filter {}

    expiration {
      days = var.object_expiration_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = var.multipart_abort_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.replica]
}

# CORS del bucket replica: solo cuando existe el ALB de la region 2 (para subir archivos durante el failover)
resource "aws_s3_bucket_cors_configuration" "replica" {
  count    = local.r2_app
  provider = aws.region2

  bucket = aws_s3_bucket.replica[0].id

  cors_rule {
    allowed_methods = ["PUT", "GET", "HEAD"]
    allowed_origins = ["http://${aws_lb.region2[0].dns_name}"]
    allowed_headers = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# ================== S3: rol y regla de replicacion ==================
data "aws_iam_policy_document" "replication_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication" {
  count = local.r2

  name               = "${var.project_name}-s3-replication-role"
  assume_role_policy = data.aws_iam_policy_document.replication_assume.json
}

data "aws_iam_policy_document" "replication" {
  count = local.r2

  statement {
    sid       = "ReadSourceConfig"
    effect    = "Allow"
    actions   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
    resources = [aws_s3_bucket.documents.arn]
  }

  statement {
    sid       = "ReadSourceObjects"
    effect    = "Allow"
    actions   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
    resources = ["${aws_s3_bucket.documents.arn}/*"]
  }

  statement {
    sid       = "WriteDestination"
    effect    = "Allow"
    actions   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
    resources = ["${aws_s3_bucket.replica[0].arn}/*"]
  }
}

resource "aws_iam_role_policy" "replication" {
  count = local.r2

  name   = "${var.project_name}-s3-replication"
  role   = aws_iam_role.replication[0].id
  policy = data.aws_iam_policy_document.replication[0].json
}

# Solo replica objetos NUEVOS desde que se activa la regla
resource "aws_s3_bucket_replication_configuration" "documents" {
  count = local.r2

  bucket = aws_s3_bucket.documents.id
  role   = aws_iam_role.replication[0].arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    filter {}

    delete_marker_replication {
      status = "Disabled"
    }

    destination {
      bucket        = aws_s3_bucket.replica[0].arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.documents,
    aws_s3_bucket_versioning.replica,
    aws_iam_role_policy.replication,
  ]
}

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

# ================== Computo en espera (solo si region2_instances > 0) ==================
data "aws_ami" "al2023_region2" {
  count    = local.r2_app
  provider = aws.region2

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

resource "aws_security_group" "alb2" {
  count    = local.r2_app
  provider = aws.region2

  name        = "${var.project_name}-alb2-sg"
  description = "Entrada HTTP hacia el ALB de la region 2"
  vpc_id      = data.aws_vpc.default[0].id
}

resource "aws_vpc_security_group_ingress_rule" "alb2_http" {
  count    = local.r2_app
  provider = aws.region2

  security_group_id = aws_security_group.alb2[0].id
  description       = "HTTP desde Internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb2_all_out" {
  count    = local.r2_app
  provider = aws.region2

  security_group_id = aws_security_group.alb2[0].id
  description       = "ALB hacia las instancias"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "app2" {
  count    = local.r2_app
  provider = aws.region2

  name        = "${var.project_name}-app2-sg"
  description = "Instancias de la region 2: solo trafico del ALB"
  vpc_id      = data.aws_vpc.default[0].id
}

resource "aws_vpc_security_group_ingress_rule" "app2_frontend" {
  count    = local.r2_app
  provider = aws.region2

  security_group_id            = aws_security_group.app2[0].id
  description                  = "Next.js desde el ALB"
  referenced_security_group_id = aws_security_group.alb2[0].id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "app2_backend" {
  count    = local.r2_app
  provider = aws.region2

  security_group_id            = aws_security_group.app2[0].id
  description                  = "NestJS desde el ALB"
  referenced_security_group_id = aws_security_group.alb2[0].id
  from_port                    = 4000
  to_port                      = 4000
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app2_all_out" {
  count    = local.r2_app
  provider = aws.region2

  security_group_id = aws_security_group.app2[0].id
  description       = "Salida libre"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "db2_postgres" {
  count    = local.r2_app
  provider = aws.region2

  security_group_id            = aws_security_group.db2[0].id
  description                  = "PostgreSQL desde las EC2 de la region 2"
  referenced_security_group_id = aws_security_group.app2[0].id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_lb" "region2" {
  count    = local.r2_app
  provider = aws.region2

  name               = "${var.project_name}-alb2"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb2[0].id]
  subnets            = data.aws_subnets.default[0].ids
}

resource "aws_lb_target_group" "frontend2" {
  count    = local.r2_app
  provider = aws.region2

  name                 = "${var.project_name}-fe2"
  port                 = 3000
  protocol             = "HTTP"
  vpc_id               = data.aws_vpc.default[0].id
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_target_group" "backend2" {
  count    = local.r2_app
  provider = aws.region2

  name                 = "${var.project_name}-be2"
  port                 = 4000
  protocol             = "HTTP"
  vpc_id               = data.aws_vpc.default[0].id
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    path                = "/api/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http2" {
  count    = local.r2_app
  provider = aws.region2

  load_balancer_arn = aws_lb.region2[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend2[0].arn
  }
}

resource "aws_lb_listener_rule" "api2" {
  count    = local.r2_app
  provider = aws.region2

  listener_arn = aws_lb_listener.http2[0].arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend2[0].arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# En la region 2 la app usa el bucket replica y la replica de RDS (de solo lectura hasta promoverla).
# La clave de la base se lee de SSM en la region principal (ssm_region).
resource "aws_launch_template" "region2" {
  count    = local.r2_app
  provider = aws.region2

  name_prefix            = "${var.project_name}-lt2-"
  image_id               = data.aws_ami.al2023_region2[0].id
  instance_type          = var.instance_type
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups             = [aws_security_group.app2[0].id]
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_type           = "gp3"
      volume_size           = var.root_volume_size
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    swap_size_mb      = var.swap_size_gb * 1024
    aws_region        = var.region2
    ssm_region        = var.aws_region
    bucket_name       = aws_s3_bucket.replica[0].bucket
    repo_url          = var.repo_url
    repo_branch       = var.repo_branch
    enable_database   = true
    db_host           = aws_db_instance.replica[0].address
    db_name           = var.db_name
    db_user           = var.db_username
    db_password_param = local.db_password_param
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-app-region2" }
  }
}

resource "aws_autoscaling_group" "region2" {
  count    = local.r2_app
  provider = aws.region2

  name                = "${var.project_name}-asg-region2"
  min_size            = 0
  max_size            = 2
  desired_capacity    = var.region2_instances
  vpc_zone_identifier = data.aws_subnets.default[0].ids
  target_group_arns   = [aws_lb_target_group.frontend2[0].arn, aws_lb_target_group.backend2[0].arn]

  health_check_type         = "ELB"
  health_check_grace_period = 900

  launch_template {
    id      = aws_launch_template.region2[0].id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app-region2"
    propagate_at_launch = true
  }
}

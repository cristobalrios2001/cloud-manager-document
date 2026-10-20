# REGION 2 · COMPUTO EN ESPERA
# ALB + Auto Scaling Group de la region 2. Solo se crea si region2_instances > 0
# (ademas de enable_region2 y enable_database). Reutiliza el mismo user_data.sh.tpl.

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

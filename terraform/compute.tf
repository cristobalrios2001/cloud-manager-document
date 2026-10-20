# SERVIDORES: Launch Template + Auto Scaling Group (reemplaza a ec2.tf)
# - Launch Template: la "receta" de una instancia (imagen, tipo, disco, rol IAM, user_data)
# - Auto Scaling Group: mantiene N instancias vivas repartidas en las 2 zonas y las
#   registra en los target groups del ALB. Si una cae, crea otra.

# BUSCA LA IMAGEN MAS RECIENTE DE AMAZON LINUX (AMI)
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

# LLAVE SSH: solo si definiste ssh_cidr
resource "aws_key_pair" "dev" {
  count = var.ssh_cidr != null ? 1 : 0

  key_name   = "${var.project_name}-key"
  public_key = file(pathexpand(var.public_key_path))
}

locals {
  user_data_primary = templatefile("${path.module}/user_data.sh.tpl", {
    swap_size_mb      = var.swap_size_gb * 1024
    aws_region        = var.aws_region
    ssm_region        = var.aws_region
    bucket_name       = aws_s3_bucket.documents.bucket
    repo_url          = var.repo_url
    repo_branch       = var.repo_branch
    enable_database   = var.enable_database
    db_host           = try(aws_db_instance.main[0].address, "")
    db_name           = var.db_name
    db_user           = var.db_username
    db_password_param = local.db_password_param
  })
}

resource "aws_launch_template" "app" {
  name_prefix            = "${var.project_name}-lt-"
  image_id               = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  key_name               = var.ssh_cidr != null ? aws_key_pair.dev[0].key_name : null
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    security_groups             = [aws_security_group.app.id]
  }

  # IMDSv2 obligatorio. hop_limit = 2 permite que los contenedores Docker lo alcancen.
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

  # Un Launch Template exige el user_data en base64
  user_data = base64encode(local.user_data_primary)

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-app" }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${var.project_name}-app" }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-asg"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.frontend.arn, aws_lb_target_group.backend.arn]

  # ELB = el ASG tambien reemplaza instancias que el ALB marque unhealthy.
  # La gracia es larga porque cada instancia compila las imagenes Docker al arrancar.
  health_check_type         = "ELB"
  health_check_grace_period = 900

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Si cambia el Launch Template, reemplaza las instancias de a una sin cortar el servicio
  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app"
    propagate_at_launch = true
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.project_name}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# SSM Session Manager: entrar a la instancia sin abrir el puerto 22
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Permisos minimos sobre el bucket (y sobre el bucket replica si existe la region 2)
locals {
  replica_bucket_arns = aws_s3_bucket.replica[*].arn
}

data "aws_iam_policy_document" "s3_access" {
  statement {
    sid       = "ListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = concat([aws_s3_bucket.documents.arn], local.replica_bucket_arns)
  }

  statement {
    sid       = "ObjectRW"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = concat(["${aws_s3_bucket.documents.arn}/*"], [for arn in local.replica_bucket_arns : "${arn}/*"])
  }
}

resource "aws_iam_role_policy" "s3_access" {
  name   = "${var.project_name}-s3-access"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.s3_access.json
}

# Leer SOLO el parametro con la clave de la base (F2)
resource "aws_iam_role_policy" "ssm_db" {
  count = local.db_on

  name = "${var.project_name}-ssm-db-password"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = aws_ssm_parameter.db_password[0].arn
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ec2.name
}

# REGION 2 · DATOS DE ARCHIVOS (S3)
# Bucket destino y regla de replicacion automatica desde el bucket principal.
# Solo se crea si enable_region2 = true (los locals r2, r2_db y r2_app estan en region2.tf).

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

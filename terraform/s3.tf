resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  bucket_name = "${var.project_name}-${random_id.bucket_suffix.hex}"

  # El navegador sube y lee archivos desde el DNS del ALB: ese es el origen que S3 debe permitir
  cors_origins = concat(["http://${aws_lb.main.dns_name}"], var.extra_cors_origins)
}

resource "aws_s3_bucket" "documents" {
  bucket        = local.bucket_name
  force_destroy = true # permite que terraform destroy borre el bucket aunque tenga archivos
}

# La replicacion entre regiones EXIGE versionado
resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Bloquea el acceso publico: los archivos solo se leen con URLs firmadas
resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  cors_rule {
    allowed_methods = ["PUT", "GET", "HEAD"]
    allowed_origins = local.cors_origins
    allowed_headers = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Con versionado, borrar deja versiones viejas: tambien se expiran para no acumular costo
resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

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

  depends_on = [aws_s3_bucket_versioning.documents]
}

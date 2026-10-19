resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  bucket_name     = "${var.project_name}-${random_id.bucket_suffix.hex}"
  frontend_origin = "http://${aws_eip.app.public_ip}:3000"
  cors_origins    = concat([local.frontend_origin], var.extra_cors_origins)
}

resource "aws_s3_bucket" "documents" {
  bucket        = local.bucket_name
  force_destroy = true # PERMITE QUE terraform destroy BORRE EL BUCKET AUNQUE TENGA ARCHIVOS
}

# BLOQUEA EL ACCESO PUBLICO, LOS ARCHIVOS SOLO SE PUEDEN LEER CON URLs FIRMADAS
resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# cONFIRUGRACIÓN DEL CORS
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

# CONFIGURACIÓN DEL CICLO DE VIDA DE LOS ARVHICOS
resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    id     = "expire-test-objects"
    status = "Enabled"

    filter {}

    expiration {
      days = var.object_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = var.multipart_abort_days
    }
  }
}
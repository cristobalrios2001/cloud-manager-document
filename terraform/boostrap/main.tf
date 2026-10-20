# BOOTSTRAP: crea UNA SOLA VEZ el bucket donde Terraform guardara el state del proyecto.
# Su propio state queda local (terraform/bootstrap/terraform.tfstate, ignorado por Git).
#
#   cd terraform/bootstrap
#   terraform init && terraform apply
#
# Copia el output state_bucket en terraform/backend.tf

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

variable "aws_region" {
  description = "Region del bucket de state (la misma de backend.tf)"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo del nombre del bucket"
  type        = string
  default     = "cloud-doc-manager"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "state" {
  bucket = "${var.project_name}-tfstate-${random_id.suffix.hex}"
}

# Versionado: permite recuperar un state anterior si algo sale mal
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket" {
  description = "Nombre del bucket: pegalo en terraform/backend.tf"
  value       = aws_s3_bucket.state.bucket
}
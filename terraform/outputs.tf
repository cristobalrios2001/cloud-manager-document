output "public_ip" {
  description = "IP pública (Elastic IP) de la instancia"
  value       = aws_eip.app.public_ip
}

output "frontend_url" {
  description = "URL del frontend (Next.js)"
  value       = "http://${aws_eip.app.public_ip}:3000"
}

output "backend_url" {
  description = "URL de la API (NestJS)"
  value       = "http://${aws_eip.app.public_ip}:4000"
}

output "bucket_name" {
  description = "Nombre del bucket S3"
  value       = aws_s3_bucket.documents.bucket
}

output "ssh_command" {
  description = "Comando para conectarse por SSH"
  value       = "ssh -i ${trimsuffix(var.public_key_path, ".pub")} ec2-user@${aws_eip.app.public_ip}"
}

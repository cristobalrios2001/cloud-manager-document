output "alb_dns_name" {
  description = "DNS del balanceador"
  value       = aws_lb.main.dns_name
}

output "app_url" {
  description = "URL de la aplicacion (entra por el ALB)"
  value       = "http://${aws_lb.main.dns_name}"
}

output "health_url" {
  description = "Health check del backend a traves del ALB"
  value       = "http://${aws_lb.main.dns_name}/api/health"
}

output "bucket_name" {
  description = "Nombre del bucket S3"
  value       = aws_s3_bucket.documents.bucket
}

output "db_endpoint" {
  description = "Endpoint de RDS (null si enable_database = false)"
  value       = try(aws_db_instance.main[0].address, null)
}

output "asg_name" {
  description = "Nombre del Auto Scaling Group (para listar sus instancias)"
  value       = aws_autoscaling_group.app.name
}

output "region2_app_url" {
  description = "URL de la aplicacion en la region 2 (null si no esta activa)"
  value       = try("http://${aws_lb.region2[0].dns_name}", null)
}

output "region2_replica_bucket" {
  description = "Bucket replica en la region 2"
  value       = try(aws_s3_bucket.replica[0].bucket, null)
}

output "promote_replica_command" {
  description = "Comando para promover la replica de RDS durante la prueba de failover"
  value = try(
    "aws rds promote-read-replica --db-instance-identifier ${aws_db_instance.replica[0].identifier} --region ${var.region2}",
    null
  )
}

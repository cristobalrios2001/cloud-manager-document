# PARAMETROS DEL PROYECTO
# Obligatoria: repo_url. Todo lo demas tiene valor por defecto.

variable "aws_region" {
  description = "Region principal de AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo para nombrar recursos y valor del tag Project"
  type        = string
  default     = "cloud-doc-manager"
}

# ---------- Red ----------
variable "vpc_cidr" {
  description = "CIDR de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs de las 2 subredes publicas (una por zona)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Se necesitan exactamente 2 subredes publicas (2 zonas de disponibilidad)."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDRs de las 2 subredes privadas (para RDS)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Se necesitan exactamente 2 subredes privadas (2 zonas de disponibilidad)."
  }
}

# ---------- Acceso ----------
variable "ssh_cidr" {
  description = "Opcional. Tu IP en formato CIDR (200.1.2.3/32) para habilitar SSH. Con null solo entras por SSM Session Manager."
  type        = string
  default     = null

  validation {
    condition     = var.ssh_cidr == null || (can(cidrhost(var.ssh_cidr, 0)) && var.ssh_cidr != "0.0.0.0/0")
    error_message = "ssh_cidr debe ser null o un CIDR valido distinto de 0.0.0.0/0."
  }
}

variable "public_key_path" {
  description = "Ruta a tu llave publica SSH (solo se usa si ssh_cidr no es null)"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

# ---------- Computo ----------
variable "instance_type" {
  description = "Tipo de instancia"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro"], var.instance_type)
    error_message = "Para controlar costos usa t2.micro o t3.micro."
  }
}

variable "root_volume_size" {
  description = "Tamano del disco raiz en GB"
  type        = number
  default     = 20
}

variable "swap_size_gb" {
  description = "Tamano del swap en GB (necesario en 1 GB de RAM)"
  type        = number
  default     = 2
}

variable "asg_min_size" {
  description = "Minimo de instancias del Auto Scaling Group"
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Instancias deseadas al crear"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximo de instancias del Auto Scaling Group"
  type        = number
  default     = 3
}

# ---------- Codigo de la aplicacion ----------
variable "repo_url" {
  description = "URL HTTPS del repositorio (publico) con docker-compose.yml en la raiz"
  type        = string
}

variable "repo_branch" {
  description = "Rama a desplegar"
  type        = string
  default     = "v2"
}

# ---------- S3 ----------
variable "object_expiration_days" {
  description = "Dias tras los cuales se eliminan los objetos de prueba"
  type        = number
  default     = 14
}

variable "multipart_abort_days" {
  description = "Dias tras los cuales se cancelan subidas multipart incompletas"
  type        = number
  default     = 7
}

variable "extra_cors_origins" {
  description = "Origenes adicionales permitidos en CORS (ej: http://localhost:3000)"
  type        = list(string)
  default     = ["http://localhost:3000"]
}

# ---------- F2: base de datos ----------
variable "enable_database" {
  description = "F2. true crea RDS PostgreSQL y conecta la aplicacion a el"
  type        = bool
  default     = false
}

variable "db_instance_class" {
  description = "Clase de instancia de RDS"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Almacenamiento de RDS en GB (gp3 pide minimo 20)"
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "true crea un standby sincronico en la segunda zona"
  type        = bool
  default     = true
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
  default     = "documents"
}

variable "db_username" {
  description = "Usuario administrador de la base de datos"
  type        = string
  default     = "docmanager"
}

# ---------- F4: region 2 ----------
variable "enable_region2" {
  description = "F4. true crea la replica de S3 y, si enable_database tambien es true, la replica de RDS"
  type        = bool
  default     = false
}

variable "region2" {
  description = "Segunda region (respaldo)"
  type        = string
  default     = "us-west-2"
}

variable "region2_instances" {
  description = "Instancias de la region 2. Dejar en 0 (pilot light); subir a 1 o 2 solo durante la prueba de failover"
  type        = number
  default     = 0
}

# ---------- Presupuesto ----------
variable "alert_email" {
  description = "Correo para las alertas de AWS Budgets. Vacio = no crea el presupuesto"
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Limite mensual del presupuesto en USD"
  type        = number
  default     = 50
}

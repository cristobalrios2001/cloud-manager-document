# PARAMETROS DEL PROYECTO
# CADA VARIABLE TIENE description, type y OPCIONALMENTE UN default
# LAS QUE NO TIENEN SON OBLIGATORIAS mi_ip y repo_url

variable "aws_region" {
  description = "Región de AWS donde se despliega todo"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefijo para nombrar recursos"
  type        = string
  default     = "cloud-doc-manager"
}

# ---------- Red ----------
variable "vpc_cidr" {
  description = "CIDR de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR de la subred pública"
  type        = string
  default     = "10.0.1.0/24"
}

# ---------- Acceso ----------
variable "my_ip" {
  description = "Tu IP pública en formato CIDR para SSH (ej: 200.1.2.3/32)"
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip, 0)) && var.my_ip != "0.0.0.0/0"
    error_message = "my_ip debe ser un CIDR válido (ej: 200.1.2.3/32) y distinto de 0.0.0.0/0."
  }
}

variable "allowed_cidr" {
  description = "CIDR con acceso a los puertos 3000 y 4000 (solo para pruebas)"
  type        = string
  default     = "0.0.0.0/0"
}

variable "public_key_path" {
  description = "Ruta a tu llave pública SSH"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

# ---------- Cómputo ----------
variable "instance_type" {
  description = "Tipo de instancia (t3.micro o t2.micro según elegibilidad Free Tier)"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro"], var.instance_type)
    error_message = "Para mantenerse en Free Tier usa t2.micro o t3.micro."
  }
}

variable "root_volume_size" {
  description = "Tamaño del disco raíz en GB"
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size <= 30
    error_message = "El Free Tier de EBS cubre hasta 30 GB."
  }
}

variable "swap_size_gb" {
  description = "Tamaño del swap en GB (necesario en 1 GB de RAM)"
  type        = number
  default     = 2
}

# ---------- Código de la aplicación ----------
variable "repo_url" {
  description = "URL HTTPS del repositorio (público) con docker-compose.yml en la raíz"
  type        = string
}

variable "repo_branch" {
  description = "Rama a desplegar"
  type        = string
  default     = "main"
}

# ---------- S3 ----------
variable "object_expiration_days" {
  description = "Días tras los cuales se eliminan los objetos de prueba"
  type        = number
  default     = 14
}

variable "multipart_abort_days" {
  description = "Días tras los cuales se cancelan subidas multipart incompletas"
  type        = number
  default     = 7
}

variable "extra_cors_origins" {
  description = "Orígenes adicionales permitidos en CORS (ej: http://localhost:3000)"
  type        = list(string)
  default     = ["http://localhost:3000"]
}

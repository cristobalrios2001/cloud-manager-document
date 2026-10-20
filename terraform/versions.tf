# QUE HERRAMIENTAS NECESITO

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    # Genera valores aleatorios (utilizado para el nombre del bucket)
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

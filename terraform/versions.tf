# QUE HERRAMIENTAS NECESITO

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Genera valores aleatorios (utilizado para el nombre del bucket)
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

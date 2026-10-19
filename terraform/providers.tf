# COMO ME CONECTO A AWS, QUE REGIÓN USAR Y QUE ETIQUETAS COLOCAR A TODO LO QUE CREE

provider "aws" {
  region = var.aws_region

  # Estos tags se aplican automáticamente a todos los recursos que los soporten
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "lab"
      ManagedBy   = "terraform"
    }
  }
}

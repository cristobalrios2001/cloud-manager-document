# COMO ME CONECTO A AWS, QUE REGION USAR Y QUE ETIQUETAS COLOCAR A TODO LO QUE CREE

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "lab"
      ManagedBy   = "terraform"
    }
  }
}

# SEGUNDA REGION (F4). Se declara siempre, pero solo se usa si enable_region2 = true.
# Los recursos de esa region llevan  provider = aws.region2

provider "aws" {
  alias  = "region2"
  region = var.region2

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "lab"
      ManagedBy   = "terraform"
    }
  }
}

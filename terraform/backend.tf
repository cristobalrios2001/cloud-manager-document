# DONDE GUARDA TERRAFORM SU STATE
# El bucket lo crea terraform/bootstrap (se hace una sola vez). Reemplaza el nombre por el que te entregue su output.

terraform {
  backend "s3" {
    bucket       = "REEMPLAZA-CON-EL-OUTPUT-DE-BOOTSTRAP"
    key          = "cloud-doc-manager/v2/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

#!/bin/bash
set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

# ---------- Swap (1 GB de RAM no alcanza para compilar) ----------
if [ ! -f /swapfile ]; then
  dd if=/dev/zero of=/swapfile bs=1M count=${swap_size_mb}
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# ---------- Docker + Compose ----------
dnf install -y docker git
systemctl enable --now docker
usermod -aG docker ec2-user

mkdir -p /usr/local/lib/docker/cli-plugins
curl -fSL "https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# ---------- Codigo ----------
git clone --branch ${repo_branch} ${repo_url} /opt/app
cd /opt/app

%{ if enable_database ~}
# ---------- Clave de la base: se lee de SSM con el Instance Profile (sin credenciales estaticas) ----------
DB_PASSWORD=$(aws ssm get-parameter --name "${db_password_param}" --with-decryption \
  --query Parameter.Value --output text --region ${ssm_region})

%{ endif ~}
# docker-compose.yml lee estas variables desde .env.
# NEXT_PUBLIC_API_URL es una ruta relativa: el ALB envia /api/* al backend.
cat > .env <<EOF
AWS_REGION=${aws_region}
S3_BUCKET_NAME=${bucket_name}
NEXT_PUBLIC_API_URL=/api
%{ if enable_database ~}
DB_HOST=${db_host}
DB_PORT=5432
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=$${DB_PASSWORD}
%{ endif ~}
EOF
chmod 600 .env

docker compose build backend
docker compose build frontend
docker compose up -d
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

# ---------- Código ----------
git clone --branch ${repo_branch} ${repo_url} /opt/app
cd /opt/app

# docker-compose.yml lee estas variables desde .env (sin credenciales AWS)
cat > .env <<EOF
AWS_REGION=${aws_region}
S3_BUCKET_NAME=${bucket_name}
NEXT_PUBLIC_API_URL=http://${public_ip}:4000
EOF

docker compose build backend
docker compose build frontend
docker compose up -d
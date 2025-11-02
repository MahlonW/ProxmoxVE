#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: community-scripts
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://goauthentik.io/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Docker"
DOCKER_CONFIG_PATH='/etc/docker/daemon.json'
mkdir -p $(dirname $DOCKER_CONFIG_PATH)
echo -e '{\n  "log-driver": "journald"\n}' >/etc/docker/daemon.json
$STD sh <(curl -fsSL https://get.docker.com)
systemctl enable -q --now docker
msg_ok "Installed Docker"

msg_info "Installing Docker Compose"
DOCKER_COMPOSE_VERSION=$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
msg_ok "Installed Docker Compose"

msg_info "Setting up Authentik"
mkdir -p /opt/authentik
cd /opt/authentik

# Download Authentik docker-compose.yml using official method
curl -fsSL https://raw.githubusercontent.com/goauthentik/authentik/main/docker-compose.yml.example -o docker-compose.yml

# Generate secrets
SECRET_KEY=$(openssl rand -base64 32)
POSTGRES_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -base64 32)

# Create .env file with required environment variables
cat <<EOF >/opt/authentik/.env
# Generated secrets - keep these safe!
AUTHENTIK_SECRET_KEY=${SECRET_KEY}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
REDIS_PASSWORD=${REDIS_PASSWORD}

# Authentik configuration
AUTHENTIK_DISABLE_UPDATE_CHECK=false
AUTHENTIK_DISABLE_STARTUP_ANALYTICS=false
EOF

# Save credentials
{
  echo "Authentik Credentials"
  echo "===================="
  echo "PostgreSQL Password: ${POSTGRES_PASSWORD}"
  echo "Redis Password: ${REDIS_PASSWORD}"
  echo "Secret Key: ${SECRET_KEY}"
  echo ""
  echo "Access URL: http://$(hostname -I | awk '{print $1}'):9000/if/flow/initial-setup/"
  echo "Initial setup will create the admin account."
} >>~/authentik.creds

msg_ok "Authentik configuration created"

msg_info "Starting Authentik containers"
cd /opt/authentik
$STD docker compose up -d
msg_ok "Authentik containers started"

msg_info "Waiting for Authentik to initialize (this may take a few minutes)..."
sleep 10
for i in {1..60}; do
  if docker compose -f /opt/authentik/docker-compose.yml ps | grep -q "Up"; then
    if curl -s http://localhost:9000/if/flow/initial-setup/ >/dev/null 2>&1; then
      msg_ok "Authentik is ready"
      break
    fi
  fi
  if [ $i -eq 60 ]; then
    msg_info "Authentik is starting up. This may take several minutes. Check status with: docker compose -f /opt/authentik/docker-compose.yml logs"
  else
    sleep 5
  fi
done

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"


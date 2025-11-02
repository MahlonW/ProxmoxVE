#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/MahlonW/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: community-scripts
# License: MIT | https://github.com/MahlonW/ProxmoxVE/raw/main/LICENSE
# Source: https://goauthentik.io/

APP="Authentik"
var_tags="${var_tags:-iam;authentication;authorization;sso}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-8192}"
var_disk="${var_disk:-20}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /opt/authentik/ ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating $APP LXC"
  $STD apt-get update
  $STD apt-get -y upgrade
  
  msg_info "Updating Docker and Docker Compose"
  $STD apt-get install --only-upgrade -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  
  if [[ -f /opt/authentik/docker-compose.yml ]]; then
    msg_info "Updating Authentik containers"
    cd /opt/authentik
    $STD docker compose pull
    $STD docker compose up -d
    msg_ok "Authentik containers updated"
  fi

  msg_info "Cleaning Up"
  $STD docker system prune -f
  $STD apt-get -y autoremove
  $STD apt-get -y autoclean
  msg_ok "Cleanup Completed"
  msg_ok "Updated successfully!"
  exit
}
start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:9000/if/flow/initial-setup/${CL}"
echo -e "${TAB}${INFO}${YW} Note: First startup may take several minutes. Check logs with: docker compose -f /opt/authentik/docker-compose.yml logs${CL}"


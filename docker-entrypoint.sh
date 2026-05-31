#!/usr/bin/env bash
set -Eeuo pipefail

export TZ="${TZ:-Asia/Riyadh}"
SSH_USER="${SSH_USER:-hosting}"
SSH_PASSWORD="${SSH_PASSWORD:-}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-}"
FORCE_PANEL_REPAIR="${FORCE_PANEL_REPAIR:-false}"

set_sshd_config() {
  local key="$1"
  local value="$2"
  local file="/etc/ssh/sshd_config"

  if grep -Eq "^[#[:space:]]*${key}[[:space:]]+" "$file"; then
    sed -i -E "s|^[#[:space:]]*${key}[[:space:]]+.*|${key} ${value}|" "$file"
  else
    printf '\n%s %s\n' "$key" "$value" >> "$file"
  fi
}

start_init_script() {
  local service="$1"
  local script="/etc/init.d/${service}"

  if [[ -x "$script" ]]; then
    "$script" start || true
  fi
}

restore_aapanel_seed() {
  if [[ "$FORCE_PANEL_REPAIR" == "true" || "$FORCE_PANEL_REPAIR" == "1" ]]; then
    echo "FORCE_PANEL_REPAIR is enabled; refreshing aaPanel panel files from image seed."
    mkdir -p /www/server
    if [[ -d /opt/aapanel-seed/server/panel ]]; then
      rm -rf /www/server/panel
      cp -a /opt/aapanel-seed/server/panel /www/server/panel
    fi
  fi

  if [[ ! -f /www/server/panel/tools.py ]]; then
    echo "Initializing /www from aaPanel seed..."
    mkdir -p /www
    cp -a /opt/aapanel-seed/. /www/
  fi
}

configure_ssh() {
  mkdir -p /run/sshd

  if ! id "$SSH_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$SSH_USER"
  fi

  usermod -aG sudo "$SSH_USER" || true

  if [[ -n "$SSH_PASSWORD" ]]; then
    echo "${SSH_USER}:${SSH_PASSWORD}" | chpasswd
    set_sshd_config PasswordAuthentication yes
  else
    set_sshd_config PasswordAuthentication no
  fi

  if [[ -n "$SSH_PUBLIC_KEY" ]]; then
    mkdir -p "/home/${SSH_USER}/.ssh"
    printf '%s\n' "$SSH_PUBLIC_KEY" > "/home/${SSH_USER}/.ssh/authorized_keys"
    chown -R "${SSH_USER}:${SSH_USER}" "/home/${SSH_USER}/.ssh"
    chmod 700 "/home/${SSH_USER}/.ssh"
    chmod 600 "/home/${SSH_USER}/.ssh/authorized_keys"
  fi

  set_sshd_config PermitRootLogin no
}

restore_aapanel_seed

# Fix common nginx cache errors when aaPanel/nginx expects this tmpfs path.
mkdir -p /dev/shm/nginx-cache/wp
chmod -R 755 /dev/shm/nginx-cache || true

configure_ssh

/usr/sbin/sshd

# Start aaPanel and common services installed through the panel.
start_init_script bt
for svc in nginx httpd mysqld mysql pure-ftpd redis; do
  start_init_script "$svc"
done

for phpinit in /etc/init.d/php-fpm-*; do
  if [[ -x "$phpinit" ]]; then
    "$phpinit" start || true
  fi
done

echo "aaPanel container started."
echo "Panel usually runs on port 7800."
echo "SSH/SFTP user: ${SSH_USER}"

# Keep the container alive for init.d-managed services.
tail -f /dev/null

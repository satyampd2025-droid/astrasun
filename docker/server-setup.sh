#!/usr/bin/env bash
# One-time setup of a fresh Ubuntu 22.04/24.04 server (run as root).
#   curl -fsSL https://raw.githubusercontent.com/satyampd2025-droid/astrasun/<branch>/docker/server-setup.sh | bash -s -- <domain> <admin-password>
set -euo pipefail
DOMAIN=${1:?usage: server-setup.sh <domain> <admin-password>}
ADMIN_PASSWORD=${2:?usage: server-setup.sh <domain> <admin-password>}
BRANCH=${BRANCH:-claude/project-thread-bqz906}
DIR=/opt/astrasun

apt-get update -y && apt-get install -y ca-certificates curl git ufw
command -v docker >/dev/null || curl -fsSL https://get.docker.com | sh
ufw allow OpenSSH && ufw allow 80 && ufw allow 443 && ufw --force enable

[ -d $DIR ] || git clone https://github.com/satyampd2025-droid/astrasun.git $DIR
cd $DIR && git fetch origin "$BRANCH" && git checkout "$BRANCH" && git pull --ff-only origin "$BRANCH"

if [ ! -f docker/.env ]; then
  cat > docker/.env <<ENV
SITE_NAME=$DOMAIN
DOMAIN=$DOMAIN
ADMIN_PASSWORD=$ADMIN_PASSWORD
DB_ROOT_PASSWORD=$(openssl rand -hex 16)
ENV
  chmod 600 docker/.env
fi

# Nightly backup at 02:00, keep 14 days (database + files)
cat > /etc/cron.d/astrasun-backup <<CRON
0 2 * * * root cd $DIR/docker && docker compose -f compose.yml -f compose.prod.yml exec -T backend bench --site $DOMAIN backup --with-files && docker compose -f compose.yml -f compose.prod.yml exec -T backend find sites/$DOMAIN/private/backups -mtime +14 -delete
CRON

bash docker/deploy.sh
echo "Done. Open https://$DOMAIN and log in as Administrator."

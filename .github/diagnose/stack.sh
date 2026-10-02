#!/usr/bin/env bash
# Helpers for the throwaway copy of the server stack (compose files in docker/). Not for the live server.
#   stack.sh up        start the stack on empty volumes and wait for the site to be created
#   stack.sh wizard    finish the setup wizard with the same answers as the real site
#   stack.sh upgrade   what docker/deploy.sh does after it rebuilt the image: recreate containers, migrate
#   stack.sh in <service> <command...>   run a command in a running container (script on stdin is fine)
#   stack.sh down      stop and delete the stack and its volumes
set -euo pipefail
SITE=mill.localhost
cd "$(dirname "$0")/../../docker"
dc() { docker compose "$@"; }
bench() { dc exec -T backend bench --site "$SITE" "$@"; }
wait_site() { dc wait create-site >/dev/null || { dc logs --tail 80 create-site; exit 1; }; }

case "${1:?usage: stack.sh up|wizard|upgrade|in|down}" in
  up)
    printf 'SITE_NAME=%s\nADMIN_PASSWORD=%s\nDB_ROOT_PASSWORD=ci-root-pass-1\nHTTP_PORT=8080\n' "$SITE" "${ADMIN_PASSWORD:?}" > .env
    dc up -d
    wait_site
    curl -fsS --retry 60 --retry-delay 5 --retry-connrefused --retry-all-errors http://localhost:8080/api/method/ping
    echo
    ;;
  wizard)
    if ! bench execute frappe.desk.page.setup_wizard.setup_wizard.setup_complete \
        --args '({"language":"English","country":"India","timezone":"Asia/Kolkata","currency":"INR","company_name":"Astrasun Global LLP","company_abbr":"AGL","chart_of_accounts":"India - Chart of Accounts","fy_start_date":"2026-04-01","fy_end_date":"2027-03-31","full_name":"Satyam","email":"wizard.owner@example.com","password":"Rehearsal-Pass-12345"},)'; then
      echo "::warning::wizard call failed, marking setup complete directly"
      bench execute frappe.db.set_single_value --args '("System Settings","setup_complete",1)'
    fi
    bench execute frappe.db.sql --args '("select (select count(*) from tabCompany) companies, (select count(*) from tabItem) items",)'
    ;;
  upgrade)
    dc up -d
    wait_site
    bench migrate
    curl -fsS --retry 60 --retry-delay 5 --retry-connrefused --retry-all-errors http://localhost:8080/api/method/ping
    echo
    ;;
  in)
    shift
    dc exec -T "$@"
    ;;
  down)
    dc down -v
    ;;
esac

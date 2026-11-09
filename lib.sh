# Shared by the other scripts: loads the settings and talks to the local bridge.
cd "$(dirname "$0")" || exit 1
[ -f .env ] || { echo "No settings yet. Run sh setup.sh first."; exit 1; }
set -a; . ./.env; set +a
BASE="http://127.0.0.1:${WAHA_PORT}"

need_docker() {
  docker info >/dev/null 2>&1 && return 0
  [ "$(uname)" = Darwin ] && open -a Docker
  i=0
  while [ $i -lt 80 ]; do
    docker info >/dev/null 2>&1 && return 0
    i=$((i + 1)); sleep 3
  done
  echo "Docker is not running. Start it and try again."; exit 1
}

# api METHOD PATH [JSON]
api() {
  if [ -n "$3" ]; then
    curl -s -m 20 -X "$1" -H "X-Api-Key: $WAHA_API_KEY" -H 'Content-Type: application/json' -d "$3" "$BASE$2"
  else
    curl -s -m 20 -X "$1" -H "X-Api-Key: $WAHA_API_KEY" "$BASE$2"
  fi
}

# Prints the session status; "?" = the bridge is not answering, "None" = no session exists yet.
status() {
  api GET /api/sessions/default | python3 -I -c 'import sys, json
try: print(json.load(sys.stdin).get("status"))
except Exception: print("?")'
}

ensure_session() {
  case "$(status)" in
    None) api POST /api/sessions '{"name":"default","start":true}' >/dev/null ;;
    STOPPED) api POST /api/sessions/default/start >/dev/null ;;
  esac
}

wait_for_api() {
  i=0
  while [ "$(status)" = "?" ] && [ $i -lt 60 ]; do i=$((i + 1)); sleep 3; done
}

# Docker Desktop forwards to 127.0.0.1; on Linux the container reaches the host at the bridge gateway.
hook_bind() {
  if [ "$(uname)" = Darwin ]; then echo 127.0.0.1
  else docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}'; fi
}

start_hook() {
  if [ -f data/hook.pid ] && kill -0 "$(cat data/hook.pid)" 2>/dev/null; then return 0; fi
  nohup python3 hook_server.py "$(hook_bind)" >> data/hook.log 2>&1 &
  echo $! > data/hook.pid
}

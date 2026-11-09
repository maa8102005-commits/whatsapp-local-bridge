#!/bin/sh
# Brings everything up. Run it after a reboot or after stop.sh.
. "$(dirname "$0")/lib.sh"
need_docker
docker compose up -d --quiet-pull || exit 1
start_hook
wait_for_api
ensure_session
i=0
while [ $i -lt 60 ]; do
  s=$(status)
  case "$s" in WORKING|SCAN_QR_CODE|FAILED) break ;; esac
  i=$((i + 1)); sleep 3
done
echo "session: $s"
case "$s" in
  WORKING) echo "Ready. Your saved login is active." ;;
  SCAN_QR_CODE|FAILED) echo "Not linked yet. Run sh link.sh to scan the QR code." ;;
esac

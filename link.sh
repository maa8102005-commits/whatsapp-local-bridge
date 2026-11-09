#!/bin/sh
# Shows a live QR code in your browser and keeps it current until your phone is linked.
. "$(dirname "$0")/lib.sh"
need_docker
docker compose up -d --quiet-pull || exit 1
start_hook
wait_for_api
ensure_session

mkdir -p data/qr
cp qr.html data/qr/index.html
publish() {
  printf 'window.BRIDGE_STATUS = "%s";\n' "$1" > data/qr/status.tmp
  mv data/qr/status.tmp data/qr/status.js
}
publish STARTING

if [ -z "$NO_OPEN" ]; then
  if [ "$(uname)" = Darwin ]; then open data/qr/index.html
  elif command -v xdg-open >/dev/null; then xdg-open data/qr/index.html >/dev/null 2>&1
  fi
fi
echo "QR page: $(pwd)/data/qr/index.html"

# Each code lasts 20 to 60 seconds, and WhatsApp issues six per session. After the last one the
# session can either go to FAILED or just sit on a dead code, so both cases restart it for a fresh set.
last_qr=""
codes=0
changed=$(date +%s)
end=$(( $(date +%s) + ${LINK_TIMEOUT:-900} ))
while [ "$(date +%s)" -lt "$end" ]; do
  s=$(status)
  publish "$s"
  case "$s" in
    WORKING)
      rm -f data/qr/qr.png
      echo "LINKED"
      exit 0 ;;
    SCAN_QR_CODE)
      if curl -sf -m 10 -H "X-Api-Key: $WAHA_API_KEY" -H 'Accept: image/png' \
          "$BASE/api/default/auth/qr" -o data/qr/qr.tmp \
          && [ "$(head -c 4 data/qr/qr.tmp | tail -c 3)" = PNG ]; then
        mv data/qr/qr.tmp data/qr/qr.png
        current=$(cksum < data/qr/qr.png)
        if [ "$current" != "$last_qr" ]; then
          last_qr=$current
          changed=$(date +%s)
          codes=$((codes + 1))
        else
          # The first code of a set lasts up to 60 seconds, the rest about 20.
          limit=30
          [ "$codes" -le 1 ] && limit=70
          if [ $(( $(date +%s) - changed )) -gt "$limit" ]; then
            publish FAILED
            api POST /api/sessions/default/restart >/dev/null
            changed=$(date +%s)
            codes=0
          fi
        fi
      fi ;;
    FAILED)
      api POST /api/sessions/default/restart >/dev/null ;;
    STOPPED|None)
      ensure_session ;;
  esac
  sleep 2
done
rm -f data/qr/qr.png
publish TIMEOUT
echo "Timed out without a scan. Run sh link.sh again."
exit 1

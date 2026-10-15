#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

if [ "$(id -u)" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

if [ ! -f "$TOR_PID_FILE" ] || ! kill -0 "$(cat "$TOR_PID_FILE")" 2>/dev/null; then
  echo "[-] Tor is not running. Start it first with activate.sh"
  exit 1
fi

OLD=$(tor_exit_ip)
echo "[*] Rotating circuit..."
kill -HUP "$(cat "$TOR_PID_FILE")"
for i in $(seq 1 15); do
  sleep 3
  NEW=$(tor_exit_ip)
  [ -n "$NEW" ] && [ "$NEW" != "$OLD" ] && break
done

if [ -n "$NEW" ]; then
  if [ "$NEW" = "$OLD" ]; then
    echo "[i] New exit IP is the same ($NEW). Retry for a fresh circuit."
  else
    echo "[+] Circuit rotated"
    echo "    Old exit: $OLD"
    echo "    New exit: $NEW"
  fi
else
  echo "[-] Could not verify new circuit"
fi

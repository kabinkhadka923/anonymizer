#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

if [ $# -eq 0 ]; then
  echo "Usage: pchain.sh <command...>"
  echo "Runs a single command through the Tor SOCKS proxy (system unchanged)."
  echo
  echo "Examples:"
  echo "  pchain.sh curl ifconfig.me"
  echo "  pchain.sh nmap -sT -Pn <target>"
  echo "  pchain.sh sqlmap -u <url>"
  exit 1
fi

if ! nc -z 127.0.0.1 9050 2>/dev/null; then
  echo "[-] Tor is not running. Start it first:"
  echo "    sudo $ROOT_DIR/activate.sh proxychains"
  exit 1
fi

echo "[*] proxychains -> Tor (SOCKS5 127.0.0.1:9050)"
exec proxychains4 -q -f "$PCHAIN_CONF" "$@"

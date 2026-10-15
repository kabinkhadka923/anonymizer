#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

echo "[*] Cleaning user shell history"
for f in "$HOME/.bash_history" "$HOME/.zsh_history" "$HOME/.python_history"; do
  [ -f "$f" ] && : > "$f" 2>/dev/null && echo "    cleared $f"
done
history -c 2>/dev/null || true

echo "[*] Removing anonymizer runtime traces"
rm -rf "$STATE_DIR" "$TOR_LOG" /tmp/anonymizer-tor.pid /tmp/anonymizer-tor.log 2>/dev/null
mkdir -p "$STATE_DIR"

echo "[*] Truncating recent logs"
for f in /var/log/auth.log /var/log/syslog /var/log/kern.log; do
  [ -f "$f" ] && sudo : > "$f" 2>/dev/null && echo "    truncated $f"
done

echo "[+] Cleanup done. Note: log wiping affects forensics and system tools."

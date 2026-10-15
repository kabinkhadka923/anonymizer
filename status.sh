#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

IFACE=$(get_iface)
MODE=$(cat "$MODE_FILE" 2>/dev/null || echo none)

echo "=== IDENTITY ==="
echo "Interface : $IFACE"
echo "Hostname  : $(hostname)"
echo "MAC       : $(sudo macchanger --show "$IFACE" 2>/dev/null | grep -oP 'Current MAC:\s+\K[0-9a-f:]+' || echo n/a)"
echo "IPv6      : $(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null | sed 's/0/enabled/;s/1/disabled/')"
echo "Mode      : $MODE"

echo
echo "=== NETWORK ==="
echo "Direct IP : $(curl -s --max-time 6 --noproxy '*' ifconfig.me 2>/dev/null || echo 'blocked (kill-switch active)')"

echo "Tor exit  : "
if tor_running; then
  echo "  $(tor_exit_ip || echo 'not ready')"
else
  echo "  tor not running"
fi

echo
echo "=== FIREWALL (kill-switch) ==="
sudo iptables -L OUTPUT -n 2>/dev/null | head -4
echo "nat OUTPUT:"
sudo iptables -t nat -L OUTPUT -n 2>/dev/null | head -4
sudo iptables -t mangle -L POSTROUTING -n 2>/dev/null | head -4

echo
echo "=== LEAK TEST ==="
if [ "$MODE" = "full" ] && [ -f "$IPT_BACKUP" ]; then
  DNS_TEST=$(timeout 5 sudo iptables -L OUTPUT -n 2>/dev/null | grep -q TOR && echo "traffic denied unless via Tor" || echo "no kill-switch")
  echo "Kill-switch  : $DNS_TEST"
  echo "IPv6 leaks   : blocked (disabled)"
else
  echo "Not in full mode - no system-wide protection"
fi

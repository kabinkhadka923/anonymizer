#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

if [ "$(id -u)" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

IFACE=$(get_iface)
MODE=$(cat "$MODE_FILE" 2>/dev/null || echo full)

echo "[*] Removing firewall rules"
iptables -D OUTPUT -j TOR 2>/dev/null
iptables -F TOR 2>/dev/null
iptables -X TOR 2>/dev/null
iptables -t nat -F OUTPUT 2>/dev/null
iptables -t mangle -F POSTROUTING 2>/dev/null
if [ -f "$IPT_BACKUP" ]; then
  iptables-restore < "$IPT_BACKUP"
  rm -f "$IPT_BACKUP"
fi

echo "[*] Stopping Tor"
if [ -f "$TOR_PID_FILE" ]; then
  kill "$(cat "$TOR_PID_FILE")" 2>/dev/null || true
  rm -f "$TOR_PID_FILE"
fi
pkill -f "$TORRC" 2>/dev/null || true

if [ "$MODE" = "full" ]; then
  echo "[*] Restoring MAC on $IFACE"
  if [ -f "$ORIG_MAC_FILE" ]; then
    ip link set "$IFACE" down
    macchanger -m "$(cat "$ORIG_MAC_FILE")" "$IFACE"
    ip link set "$IFACE" up
    rm -f "$ORIG_MAC_FILE"
  fi

  echo "[*] Restoring hostname"
  if [ -f "$ORIG_HOSTNAME_FILE" ]; then
    hostnamectl set-hostname "$(cat "$ORIG_HOSTNAME_FILE")" 2>/dev/null || hostname "$(cat "$ORIG_HOSTNAME_FILE")"
    rm -f "$ORIG_HOSTNAME_FILE"
  fi

  echo "[*] Re-enabling IPv6"
  if [ -f "$IPV6_FILE" ]; then
    sysctl -q -w net.ipv6.conf.all.disable_ipv6="$(cat "$IPV6_FILE")" net.ipv6.conf.default.disable_ipv6="$(cat "$IPV6_FILE")"
    rm -f "$IPV6_FILE"
  fi
fi

rm -f "$IFACE_FILE" "$MODE_FILE"
echo "[+] DEACTIVATED - network restored to normal"

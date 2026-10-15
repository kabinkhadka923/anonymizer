#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

usage() {
  echo "Usage: activate.sh [MODE] [--iface INTERFACE] [--mac VENDOR|RANDOM]"
  echo
  echo "Modes:"
  echo "  full        transparent Tor routing + kill switch + spoofing (default)"
  echo "  proxychains system unchanged; anonymize per-command with pchain.sh"
  echo
  echo "Options:"
  echo "  --iface X   network interface (auto-detected by default)"
  echo "  --mac X     MAC strategy: RANDOM (full random) or VENDOR (real vendor prefix)"
  exit 0
}

if [ "$(id -u)" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

MODE="full"
IFACE=""
MAC_MODE="VENDOR"

while [ $# -gt 0 ]; do
  case "$1" in
    full|proxychains) MODE="$1"; shift ;;
    --iface) IFACE="$2"; shift 2 ;;
    --mac) MAC_MODE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) shift ;;
  esac
done

mkdir -p "$STATE_DIR"
IFACE="${IFACE:-$(get_iface)}"
echo "$IFACE" > "$IFACE_FILE"
echo "$MODE" > "$MODE_FILE"

echo "[*] Mode: $MODE  Interface: $IFACE"

if [ "$MODE" = "proxychains" ]; then
  if ! pgrep -f "$TORRC" >/dev/null 2>&1; then
    echo "[*] Starting Tor (background service only)"
    systemctl stop tor 2>/dev/null || true
    pkill -f "$TORRC" 2>/dev/null || true
    rm -f "$TOR_PID_FILE" "$TOR_LOG"
    setsid tor --defaults-torrc /dev/null -f "$TORRC" > "$TOR_LOG" 2>&1 < /dev/null &
    sleep 2
  fi
  echo "[*] Waiting for Tor circuit"
  for i in $(seq 1 30); do
    EXIT_IP=$(tor_exit_ip)
    [ -n "$EXIT_IP" ] && break
    sleep 2
  done
  if [ -z "$EXIT_IP" ]; then
    echo "[-] Tor failed to bootstrap:"; tail -15 "$TOR_LOG" 2>/dev/null
    exit 1
  fi
  echo "[+] READY - use: $ROOT_DIR/pchain.sh <command>"
  echo "    Tor exit: $EXIT_IP"
  exit 0
fi

if [ ! -f "$ORIG_MAC_FILE" ]; then
  ORIG=$(macchanger --show "$IFACE" 2>/dev/null | grep -oP 'Current MAC:\s+\K[0-9a-f:]+')
  echo "${ORIG:-$(cat /sys/class/net/$IFACE/address)}" > "$ORIG_MAC_FILE"
fi

echo "[*] Spoofing MAC on $IFACE"
ip link set "$IFACE" down
if [ "$MAC_MODE" = "RANDOM" ]; then
  macchanger -r "$IFACE"
else
  macchanger -A "$IFACE"
fi
ip link set "$IFACE" up

if [ ! -f "$ORIG_HOSTNAME_FILE" ]; then
  hostname > "$ORIG_HOSTNAME_FILE"
  NEWHOST="host-$(cat /dev/urandom | tr -dc 'a-z0-9' | head -c 8)"
  echo "[*] Spoofing hostname -> $NEWHOST"
  hostnamectl set-hostname "$NEWHOST" 2>/dev/null || hostname "$NEWHOST"
fi

if [ ! -f "$IPV6_FILE" ]; then
  echo "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)" > "$IPV6_FILE"
  echo "[*] Disabling IPv6 (leak prevention)"
  sysctl -q -w net.ipv6.conf.all.disable_ipv6=1 net.ipv6.conf.default.disable_ipv6=1
fi

echo "[*] Starting Tor"
systemctl stop tor 2>/dev/null || true
pkill -f "$TORRC" 2>/dev/null || true
rm -f "$TOR_PID_FILE" "$TOR_LOG"
setsid tor --defaults-torrc /dev/null -f "$TORRC" > "$TOR_LOG" 2>&1 < /dev/null &

echo "[*] Waiting for Tor circuit"
for i in $(seq 1 30); do
  if [ -f "$TOR_PID_FILE" ]; then
    EXIT_IP=$(tor_exit_ip)
    [ -n "$EXIT_IP" ] && break
  fi
  sleep 2
done

echo "[*] Verifying real Tor exit (IsTor check)"
REAL_TOR="no"
for i in $(seq 1 10); do
  if tor_is_real; then REAL_TOR="yes"; break; fi
  sleep 2
done

if [ -z "$EXIT_IP" ]; then
  echo "[-] Tor failed to bootstrap:"
  tail -20 "$TOR_LOG" 2>/dev/null
  echo "[-] Rolling back..."
  "$ROOT_DIR/deactivate.sh"
  exit 1
fi

if [ "$REAL_TOR" != "yes" ]; then
  DIP=$(direct_ip)
  echo "[-] Tor is NOT providing anonymity on this network."
  echo "    check.torproject.org reports IsTor:false"
  echo "    Direct IP   : ${DIP:-unknown}"
  echo "    Tor exit IP : $EXIT_IP"
  echo "    This network is MITM'd or transparently proxied - Tor cannot work here."
  echo "[-] Rolling back (no firewall was applied)."
  "$ROOT_DIR/deactivate.sh"
  echo "[i] Options: use a VPN instead, or proxychains mode, or a different network."
  exit 1
fi
echo "[*] Tor exit IP: $EXIT_IP (IsTor:true)"

echo "[*] Applying kill-switch firewall (fail-closed)"
iptables-save > "$IPT_BACKUP"
iptables -t nat -F OUTPUT
iptables -N TOR 2>/dev/null || iptables -F TOR
iptables -F TOR
iptables -A TOR -m owner --uid-owner "$TOR_UID" -j RETURN
iptables -A TOR -d 127.0.0.0/8 -j RETURN
iptables -A TOR -d 10.192.0.0/10 -j RETURN
iptables -A TOR -p udp --dport 68 -j RETURN
iptables -A TOR -j REJECT
iptables -I OUTPUT -j TOR
iptables -t nat -A OUTPUT -o lo -j RETURN
iptables -t nat -A OUTPUT -m owner --uid-owner "$TOR_UID" -j RETURN
iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 5353
iptables -t nat -A OUTPUT -d 10.192.0.0/10 -j RETURN
iptables -t nat -A OUTPUT -p tcp -j REDIRECT --to-ports 9040
iptables -t mangle -A POSTROUTING -j TTL --ttl-set 64 2>/dev/null || true

FINAL_IP=$(tor_exit_ip)
echo "[+] ACTIVATED"
echo "    Mode      : full (transparent routing)"
echo "    Interface : $IFACE"
echo "    MAC       : $(macchanger --show "$IFACE" 2>/dev/null | grep -oP 'Current MAC:\s+\K[0-9a-f:]+')"
echo "    Hostname  : $(hostname)"
echo "    IPv6      : disabled"
echo "    Exit IP   : $FINAL_IP"
echo "    Rotate    : $ROOT_DIR/circuit.sh"
echo "    Deactivate: $ROOT_DIR/deactivate.sh"

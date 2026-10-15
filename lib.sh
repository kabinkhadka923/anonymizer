#!/usr/bin/env bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$ROOT_DIR/state"
IFACE_FILE="$STATE_DIR/iface"
ORIG_MAC_FILE="$STATE_DIR/orig_mac"
ORIG_HOSTNAME_FILE="$STATE_DIR/orig_hostname"
IPV6_FILE="$STATE_DIR/ipv6_orig"
IPT_BACKUP="$STATE_DIR/iptables.backup"
TORRC="$ROOT_DIR/torrc"
TOR_LOG="/tmp/anonymizer-tor.log"
TOR_PID_FILE="/tmp/anonymizer-tor.pid"
MODE_FILE="$STATE_DIR/mode"
PCHAIN_CONF="$ROOT_DIR/proxychains.conf"
TOR_UID=$(id -u debian-tor 2>/dev/null || echo 132)

get_iface() {
  if [ -s "$IFACE_FILE" ]; then
    cat "$IFACE_FILE"
  elif ip route get 1.1.1.1 >/dev/null 2>&1; then
    ip route get 1.1.1.1 | grep -oP 'dev \K\S+' | head -1
  else
    for i in eth0 eth1 wlan0 wlan1 ens32 ens33 ens18 enp0s3; do
      [ -d "/sys/class/net/$i" ] && { echo "$i"; return; }
    done
    echo eth0
  fi
}

tor_running() {
  [ -f "$TOR_PID_FILE" ] && kill -0 "$(cat "$TOR_PID_FILE")" 2>/dev/null
}

tor_exit_ip() {
  local ip=""
  ip=$(curl -s --max-time 10 --socks5-hostname 127.0.0.1:9050 --noproxy '*' https://check.torproject.org/api/ip 2>/dev/null | grep -oP '"IP":"\K[0-9.]+')
  if [ -z "$ip" ]; then
    ip=$(curl -s --max-time 10 --socks5-hostname 127.0.0.1:9050 --noproxy '*' https://ipinfo.io/ip 2>/dev/null | grep -oP '^[0-9.]+$')
  fi
  [ -z "$ip" ] && ip=$(curl -s --max-time 10 --socks5-hostname 127.0.0.1:9050 --noproxy '*' http://ip-api.com/line/?fields=query 2>/dev/null | grep -oP '^[0-9.]+$')
  echo "$ip"
}

tor_is_real() {
  local ip=""
  ip=$(curl -s --max-time 12 --socks5-hostname 127.0.0.1:9050 --noproxy '*' https://check.torproject.org/api/ip 2>/dev/null | grep -oP '"IsTor":\K[a-z]+')
  [ "$ip" = "true" ]
}

direct_ip() {
  curl -s --max-time 8 --noproxy '*' http://ip-api.com/line/?fields=query 2>/dev/null | grep -oP '^[0-9.]+$'
}

is_ip() {
  echo "$1" | grep -qP '^([0-9]{1,3}\.){3}[0-9]{1,3}$'
}

rand_mac() {
  cat /dev/urandom 2>/dev/null | od -An -N6 -tx1 | tr -d ' \n' | sed 's/\(..\)/\1:/g' | sed 's/:$//'
}

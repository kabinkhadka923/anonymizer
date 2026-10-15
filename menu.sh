#!/usr/bin/env bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while true; do
  CHOICE=$(zenity --list \
    --title="Anonymizer" \
    --text="Advanced anonymization toolkit" \
    --column="Action" --column="Description" --width=640 --height=420 \
    "Activate" "Kill-switch: all traffic through Tor + MAC/hostname spoof + IPv6 off" \
    "Proxychains mode" "Only start Tor; wrap commands individually" \
    "Rotate circuit" "Request a new Tor exit IP" \
    "Hardened Firefox" "Launch isolated anti-fingerprint browser (proxy it with pchain.sh)" \
    "Status" "Full identity / network / firewall / leak check" \
    "Wipe" "Clear shell history + anonymizer runtime traces" \
    "Deactivate" "Restore MAC, hostname, IPv6, firewall; stop Tor" \
    "Exit" "Close this window" 2>/dev/null)

  case "$CHOICE" in
    Activate|Proxychains*)
      LOG=$(mktemp)
      MODE=full
      echo "$CHOICE" | grep -q "Proxychains" && MODE=proxychains
      (echo "5"; echo "# Spoofing and starting Tor...";
       sudo "$ROOT_DIR/activate.sh" "$MODE" >> "$LOG" 2>&1; echo "100") |
        zenity --progress --pulsate --auto-close --title="Anonymizer" --text="Activating..." 2>/dev/null
      zenity --info --title="Anonymizer" --text="$(tail -15 "$LOG")" --width=540 2>/dev/null
      rm -f "$LOG"
      ;;
    Rotate*)
      OUT=$(sudo "$ROOT_DIR/circuit.sh" 2>&1)
      zenity --info --title="Anonymizer" --text="$OUT" --width=480 2>/dev/null
      ;;
    Hardened*)
      "$ROOT_DIR/hardened_firefox.sh"
      zenity --info --title="Anonymizer" --text="Hardened Firefox launched.\nRemember to proxy it:\n  ~/Desktop/anonymizer/pchain.sh firefox" --width=480 2>/dev/null
      ;;
    Status)
      OUT=$("$ROOT_DIR/status.sh" 2>&1)
      zenity --info --title="Anonymizer" --text="$OUT" --width=560 --height=440 2>/dev/null
      ;;
    Wipe)
      zenity --question --title="Anonymizer" --text="Wipe shell history and anonymizer traces?" 2>/dev/null && {
        OUT=$(bash "$ROOT_DIR/wipe.sh" 2>&1)
        zenity --info --title="Anonymizer" --text="$OUT" --width=520 2>/dev/null
      }
      ;;
    Deactivate)
      LOG=$(mktemp)
      (echo "10"; echo "# Restoring network...";
       sudo "$ROOT_DIR/deactivate.sh" >> "$LOG" 2>&1; echo "100") |
        zenity --progress --pulsate --auto-close --title="Anonymizer" --text="Deactivating..." 2>/dev/null
      zenity --info --title="Anonymizer" --text="$(tail -10 "$LOG")" --width=540 2>/dev/null
      rm -f "$LOG"
      ;;
    Exit|"")
      break
      ;;
  esac
done

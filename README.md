# Anonymizer (Kali) — Advanced

Advanced anonymization toolkit on your Desktop.

## Location
`~/Desktop/anonymizer/`

## Quick start
- **GUI button:** double-click `Anonymizer.desktop` (right-click -> "Allow Launching" if needed), or run `anonymizer`
- **Activate (full):** `sudo anonymize` — kill-switch, MAC+hostname spoof, IPv6 off, all traffic through Tor
- **Per-command mode:** `sudo anonymize proxychains` then `pchain.sh <cmd>`
- **Deactivate:** `sudo deanonymize`
- **Status / leaks:** `status.sh`
- **Rotate exit IP:** `sudo circuit.sh`

## Global commands (symlinked)
`anonymize`, `deanonymize`, `anonymizer` (GUI menu), `pchain` (proxy wrapper), `circuit` (rotate)

## What full mode does
1. **MAC spoof** — `VENDOR` mode uses a real vendor prefix (macchanger -A), `--mac RANDOM` for full random
2. **Hostname spoof** — random transient hostname (original restored on deactivate)
3. **IPv6 disable** — blocks IPv6 leak path
4. **Tor** — dedicated instance (SOCKS 9050, TransPort 9040, DNSPort 5353, ControlPort 9051)
5. **Kill-switch iptables** — OUTPUT chained to `TOR`; everything not owned by tor, not loopback, not the tor virtual net, not DHCP is **REJECTed** (fail-closed, nothing leaks even if Tor dies)
6. **DNS over Tor** — all port-53 UDP redirected to Tor's DNSPort
7. **TTL normalization** — outgoing TTL set to 64 (mangle)
8. Original iptables/MAC/hostname/IPv6 saved in `state/` for restore

## Utilities
| Tool | Purpose |
|---|---|
| `circuit.sh` | SIGHUP tor, verify a new exit IP |
| `pchain.sh <cmd>` | Run one command through Tor SOCKS (proxychains4) |
| `hardened_firefox.sh` | Isolated profile: resist fingerprinting, WebRTC/WebGL off, HTTPS-only, no cache |
| `wipe.sh` | Clear shell history + anonymizer traces + rotate system logs |
| `status.sh` | Identity, network, firewall, leak checks |

## Verify
```bash
status.sh
curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip   # IsTor true + exit IP
```

## Notes / risks
- While active, LAN is reachable (DHCP allowed); everything else is Tor-only. Some sites block Tor exits.
- `wipe.sh` modifies system logs — use only when authorized; it reduces forensic value.
- Full mode breaks VPNs and THM's browser attackbox; use `proxychains` mode for those.
- This raises the bar against casual tracking; it is not absolute anonymity.

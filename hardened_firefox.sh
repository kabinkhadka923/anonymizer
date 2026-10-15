#!/usr/bin/env bash
PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/firefox-profile"
mkdir -p "$PROFILE_DIR"

cat > "$PROFILE_DIR/user.js" <<'EOF'
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);
user_pref("privacy.trackingprotection.cryptomining.enabled", true);
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.firstparty.isolate", true);
user_pref("privacy.donottrackheader.enabled", true);
user_pref("dom.security.https_only_mode", true);
user_pref("media.peerconnection.enabled", false);
user_pref("media.navigator.enabled", false);
user_pref("webgl.disabled", true);
user_pref("geo.enabled", false);
user_pref("geo.provider.use_gpsd", false);
user_pref("browser.safebrowsing.enabled", false);
user_pref("browser.send_pings", false);
user_pref("beacon.enabled", false);
user_pref("network.http.referer.XOriginPolicy", 2);
user_pref("network.http.referer.trimmingPolicy", 2);
user_pref("browser.cache.disk.enable", false);
user_pref("browser.cache.memory.enable", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("browser.ping-centre.telemetry", false);
user_pref("extensions.pocket.enabled", false);
user_pref("browser.urlbar.suggest.searches", false);
user_pref("browser.search.suggest.enabled", false);
user_pref("places.history.enabled", false);
user_pref("signon.rememberSignons", false);
user_pref("security.certerrors.mitm.auto_enable_enterprise_roots", false);
user_pref("network.cookie.lifetimePolicy", 2);
user_pref("network.http.warn-on-off", true);
user_pref("browser.shell.checkDefaultBrowser", false);
EOF

if [ "$(id -u)" -eq 0 ]; then
  exec sudo -u kali firefox --new-instance --profile "$PROFILE_DIR" 2>/dev/null &
else
  firefox --new-instance --profile "$PROFILE_DIR" 2>/dev/null &
fi

echo "[+] Hardened Firefox launched with isolated profile: $PROFILE_DIR"
echo "    Resist fingerprinting, tracking blocked, WebRTC/WebGL off, HTTPS-only, no cache."

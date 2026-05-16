#!/usr/bin/env bash
set -euo pipefail

APP="${1:?app bundle path required}"
HELPER_ID="io.github.jinnyday0719.mfanctl.helper"
HELPER_SRC="$APP/Contents/Library/PrivilegedHelperTools/$HELPER_ID"
HELPER_DST="/Library/PrivilegedHelperTools/$HELPER_ID"
PLIST="/Library/LaunchDaemons/$HELPER_ID.plist"
SOCKET="/var/run/$HELPER_ID.sock"

if [[ ! -x "$HELPER_SRC" ]]; then
  echo "helper not found in app bundle: $HELPER_SRC" >&2
  exit 1
fi

mkdir -p /Library/PrivilegedHelperTools
cp "$HELPER_SRC" "$HELPER_DST"
chown root:wheel "$HELPER_DST"
chmod 755 "$HELPER_DST"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$HELPER_ID</string>
  <key>ProgramArguments</key>
  <array>
    <string>$HELPER_DST</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/var/log/$HELPER_ID.log</string>
  <key>StandardErrorPath</key>
  <string>/var/log/$HELPER_ID.log</string>
</dict>
</plist>
PLIST

chown root:wheel "$PLIST"
chmod 644 "$PLIST"

launchctl bootout "system/$HELPER_ID" >/dev/null 2>&1 || true
rm -f "$SOCKET"
launchctl enable "system/$HELPER_ID" >/dev/null 2>&1 || true
launchctl bootstrap system "$PLIST"
launchctl kickstart -k "system/$HELPER_ID"

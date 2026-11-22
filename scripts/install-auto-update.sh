#!/bin/bash
# Richtet die automatische Floof-Aktualisierung auf diesem Mac ein (einmalig).
# Aufruf:  bash install-auto-update.sh

set -euo pipefail

echo ""
echo "🐰  Floof – automatische Aktualisierung einrichten"
echo "------------------------------------------------"
echo ""

SUPPORT="$HOME/Library/Application Support/Floof"
CONFIG="$SUPPORT/config"
AGENT="$HOME/Library/LaunchAgents/app.floof.autoupdate.plist"
mkdir -p "$SUPPORT" "$HOME/Library/LaunchAgents"

# 1. Projektordner (wird bei Bedarf von GitHub geholt)
DEFAULT_REPO="$HOME/Floof-App"
read -r -p "Wo soll das Floof-Projekt liegen? [$DEFAULT_REPO] " REPO_DIR
REPO_DIR="${REPO_DIR:-$DEFAULT_REPO}"
if [ ! -d "$REPO_DIR/.git" ]; then
    echo "→ Projekt wird von GitHub geladen …"
    git clone -b claude/gracious-pasteur-aedufe https://github.com/cz8hy6d2wr-debug/Floof.git "$REPO_DIR"
fi

# 2. Team-ID und Bundle-ID – wenn möglich aus einem alten Download übernehmen
echo ""
echo "Team-ID und Bundle-ID findest du in Xcode unter Floof → Signing & Capabilities."
echo "Tipp: Ziehe den Ordner deines bisherigen Floof-Downloads hier hinein, dann lese ich sie aus."
read -r -p "Alter Floof-Ordner (oder Enter zum Überspringen): " OLD_DIR
OLD_DIR="${OLD_DIR%/}"; OLD_DIR="${OLD_DIR//\\ / }"
TEAM_GUESS=""; BUNDLE_GUESS=""
if [ -n "$OLD_DIR" ] && [ -f "$OLD_DIR/Floof.xcodeproj/project.pbxproj" ]; then
    TEAM_GUESS=$(grep -m1 -o 'DEVELOPMENT_TEAM = [A-Z0-9]*' "$OLD_DIR/Floof.xcodeproj/project.pbxproj" | awk '{print $3}' || true)
    BUNDLE_GUESS=$(grep -m1 -o 'PRODUCT_BUNDLE_IDENTIFIER = [^;]*' "$OLD_DIR/Floof.xcodeproj/project.pbxproj" | awk '{print $3}' || true)
fi
read -r -p "Team-ID [${TEAM_GUESS:-z. B. AB12CD34EF}]: " TEAM_ID
TEAM_ID="${TEAM_ID:-$TEAM_GUESS}"
read -r -p "Bundle-ID [${BUNDLE_GUESS:-app.floof.diary}]: " BUNDLE_ID
BUNDLE_ID="${BUNDLE_ID:-${BUNDLE_GUESS:-app.floof.diary}}"
[ -n "$TEAM_ID" ] || { echo "Team-ID fehlt."; exit 1; }

# 3. iPhone auswählen
echo ""
echo "Verbundene Geräte:"
xcrun devicectl list devices 2>/dev/null || true
echo ""
read -r -p "Name deines iPhones (wie oben angezeigt): " DEVICE
[ -n "$DEVICE" ] || { echo "Gerät fehlt."; exit 1; }

cat > "$CONFIG" <<CONF
REPO_DIR="$REPO_DIR"
TEAM_ID="$TEAM_ID"
BUNDLE_ID="$BUNDLE_ID"
DEVICE="$DEVICE"
CONF

# 4. Zeitplan: montags und donnerstags um 20:00 (verpasste Termine holt macOS beim Aufwachen nach)
SCRIPT="$REPO_DIR/scripts/floof-update.sh"
chmod +x "$SCRIPT"
cat > "$AGENT" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>app.floof.autoupdate</string>
    <key>ProgramArguments</key>
    <array><string>/bin/bash</string><string>$SCRIPT</string></array>
    <key>StartCalendarInterval</key>
    <array>
        <dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>20</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>4</integer><key>Hour</key><integer>20</integer><key>Minute</key><integer>0</integer></dict>
    </array>
</dict>
</plist>
PLIST
launchctl bootout "gui/$(id -u)" "$AGENT" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$AGENT"

echo ""
echo "✓ Eingerichtet: Floof wird montags und donnerstags um 20 Uhr aktualisiert."
echo "  Protokoll: ~/Library/Logs/Floof-Update.log"
echo ""
read -r -p "Jetzt einmal testen? [J/n] " NOW
if [ "${NOW:-J}" != "n" ] && [ "${NOW:-J}" != "N" ]; then
    bash "$SCRIPT"
    tail -n 5 "$HOME/Library/Logs/Floof-Update.log"
fi

#!/bin/bash
# Floof automatisch aktualisieren und auf das iPhone installieren.
# Wird vom Mac zweimal pro Woche gestartet (siehe install-auto-update.sh).
# Frische Signatur = die App läuft mit kostenlosem Apple-Account weiter.

set -uo pipefail

CONFIG="$HOME/Library/Application Support/Floof/config"
LOG="$HOME/Library/Logs/Floof-Update.log"
mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1
echo ""
echo "=== $(date '+%d.%m.%Y %H:%M') ==="

notify() {  # $1 Titel, $2 Text
    osascript -e "display notification \"$2\" with title \"$1\"" >/dev/null 2>&1 || true
}

fail() {
    echo "FEHLER: $1"
    notify "Floof-Update fehlgeschlagen" "$1 – Details: ~/Library/Logs/Floof-Update.log"
    exit 1
}

[ -f "$CONFIG" ] || fail "Keine Einstellungen gefunden. Bitte install-auto-update.sh ausführen."
# shellcheck source=/dev/null
source "$CONFIG"
: "${REPO_DIR:?}" "${TEAM_ID:?}" "${BUNDLE_ID:?}" "${DEVICE:?}"

cd "$REPO_DIR" || fail "Projektordner $REPO_DIR nicht gefunden."

echo "→ Neueste Version holen"
git pull --ff-only || fail "Code konnte nicht aktualisiert werden (git pull)."

echo "→ App bauen und signieren"
xcodebuild \
    -project Floof.xcodeproj \
    -target Floof \
    -sdk iphoneos \
    -configuration Release \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    CODE_SIGN_STYLE=Automatic \
    -allowProvisioningUpdates \
    build -quiet || fail "Die App konnte nicht gebaut werden."

APP="$REPO_DIR/build/Release-iphoneos/Floof.app"
[ -d "$APP" ] || fail "Gebaute App nicht gefunden."

echo "→ Auf dem iPhone installieren ($DEVICE)"
xcrun devicectl device install app --device "$DEVICE" "$APP" \
    || fail "iPhone nicht erreichbar. Entsperrt, im selben WLAN und in Xcode per Netzwerk verbunden?"

echo "✓ Fertig"
notify "Floof aktualisiert" "Neueste Version installiert – läuft wieder 7 Tage."

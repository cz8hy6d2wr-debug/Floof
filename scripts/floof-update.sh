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
: "${REPO_DIR:?}" "${TEAM_ID:?}" "${BUNDLE_ID:?}"
# Versehentlich mitkopiertes "OU=" (aus dem Zertifikat) und Leerzeichen entfernen.
TEAM_ID="$(echo "${TEAM_ID#OU=}" | tr -d '[:space:]')"
# Mehrere iPhones, getrennt durch "|" (ältere Einstellungen mit nur DEVICE gehen weiter).
DEVICES="${DEVICES:-${DEVICE:-}}"
[ -n "$DEVICES" ] || fail "Kein iPhone eingetragen."

cd "$REPO_DIR" || fail "Projektordner $REPO_DIR nicht gefunden."

echo "→ Neueste Version holen"
BEFORE="$(git hash-object "$0" 2>/dev/null || true)"
git pull --ff-only || fail "Code konnte nicht aktualisiert werden (git pull)."
# Hat sich dieses Skript selbst geändert? Dann gleich mit der neuen Fassung weitermachen.
if [ -z "${FLOOF_REEXEC:-}" ] && [ "$BEFORE" != "$(git hash-object "$0" 2>/dev/null || true)" ]; then
    echo "→ Update-Skript wurde erneuert, starte neu"
    FLOOF_REEXEC=1 exec /bin/bash "$0" "$@"
fi

build() {  # $@ zusätzliche Build-Einstellungen
    xcodebuild \
        -project Floof.xcodeproj \
        -target Floof \
        -sdk iphoneos \
        -configuration Release \
        DEVELOPMENT_TEAM="$TEAM_ID" \
        FLOOF_BUNDLE_ID="$BUNDLE_ID" \
        CODE_SIGN_STYLE=Automatic \
        -allowProvisioningUpdates \
        "$@" \
        build -quiet
}

echo "→ App bauen und signieren (mit Widgets)"
if ! build; then
    # Kostenlose Apple-Accounts erlauben die App-Gruppe nicht immer. Dann ohne sie bauen:
    # Die App läuft normal, die Widgets zeigen nur "Floof öffnen".
    echo "→ Zweiter Versuch ohne App-Gruppe"
    build CODE_SIGN_ENTITLEMENTS= || fail "Die App konnte nicht gebaut werden."
    notify "Floof: Widgets eingeschränkt" "Dein Apple-Account erlaubt keine App-Gruppe – die App läuft, Widgets zeigen keine Daten."
fi

APP="$REPO_DIR/build/Release-iphoneos/Floof.app"
[ -d "$APP" ] || fail "Gebaute App nicht gefunden."

OK=(); MISSED=()
IFS='|' read -ra LIST <<< "$DEVICES"
for device in "${LIST[@]}"; do
    device="$(echo "$device" | xargs)"   # Leerzeichen am Rand entfernen
    [ -n "$device" ] || continue
    echo "→ Installieren auf: $device"
    if xcrun devicectl device install app --device "$device" "$APP"; then
        OK+=("$device")
    else
        echo "   nicht erreichbar: $device"
        MISSED+=("$device")
    fi
done

if [ ${#MISSED[@]} -eq 0 ]; then
    echo "✓ Fertig"
    notify "Floof aktualisiert" "Auf ${#OK[@]} iPhone(s) installiert – läuft wieder 7 Tage."
else
    missed="$(IFS=', '; echo "${MISSED[*]}")"
    notify "Floof: nicht alle iPhones erreicht" "Nicht erreicht: $missed. Entsperrt und im selben WLAN? Nächster Versuch beim nächsten Termin."
    [ ${#OK[@]} -gt 0 ] || exit 1
fi

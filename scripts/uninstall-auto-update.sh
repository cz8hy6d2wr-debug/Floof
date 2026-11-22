#!/bin/bash
# Schaltet die automatische Floof-Aktualisierung wieder ab.
AGENT="$HOME/Library/LaunchAgents/app.floof.autoupdate.plist"
launchctl bootout "gui/$(id -u)" "$AGENT" 2>/dev/null || true
rm -f "$AGENT"
echo "✓ Automatische Aktualisierung abgeschaltet."

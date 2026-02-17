#!/bin/bash
# AGS Dock toggle — replaces the old eww dock toggle
# This script toggles the AGS dock panel visibility

ags toggle dock 2>/dev/null || {
    echo "AGS dock toggle failed — is ags running?"
    notify-send "Dock" "AGS is not running. Start it with: ags run" \
        --icon="dialog-warning" \
        --urgency=normal
}

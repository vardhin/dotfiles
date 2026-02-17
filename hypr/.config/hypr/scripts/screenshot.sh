#!/bin/bash

# Screenshot utility for Hyprland
# Dependencies: grim, slurp, wl-clipboard, libnotify, swappy (optional)

SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
TEMP_DIR="/tmp"
DATE=$(date '+%Y-%m-%d_%H-%M-%S')

# Create screenshot directory if it doesn't exist
mkdir -p "$SCREENSHOT_DIR"

# Function to send notification
notify_screenshot() {
    local file="$1"
    local action="$2"
    
    if [[ -f "$file" ]]; then
        notify-send "Screenshot $action" "Saved to $(basename "$file")" \
            --icon="$file" \
            --app-name="Screenshot" \
            --urgency=low \
            --expire-time=3000
    else
        notify-send "Screenshot Failed" "Could not $action screenshot" \
            --icon="dialog-error" \
            --app-name="Screenshot" \
            --urgency=critical
    fi
}

# Function to copy to clipboard and save
copy_and_save() {
    local temp_file="$1"
    local final_file="$2"
    local action="$3"
    
    if [[ -f "$temp_file" ]]; then
        # Copy to clipboard
        wl-copy < "$temp_file"
        
        # Move to final location
        mv "$temp_file" "$final_file"
        
        notify_screenshot "$final_file" "$action"
        echo "$final_file"
    else
        notify-send "Screenshot Failed" "Could not capture screenshot" \
            --icon="dialog-error" \
            --urgency=critical
        exit 1
    fi
}

# Function to open in editor (swappy)
edit_screenshot() {
    local file="$1"
    if command -v swappy >/dev/null 2>&1; then
        swappy -f "$file" -o "$file"
    fi
}

case "$1" in
    "fullscreen"|"screen")
        temp_file="$TEMP_DIR/screenshot_$DATE.png"
        final_file="$SCREENSHOT_DIR/fullscreen_$DATE.png"
        
        grim "$temp_file"
        copy_and_save "$temp_file" "$final_file" "taken (fullscreen)"
        ;;
        
    "area"|"region")
        temp_file="$TEMP_DIR/screenshot_$DATE.png"
        final_file="$SCREENSHOT_DIR/area_$DATE.png"
        
        # Use slurp to select area, then grim to capture
        if area=$(slurp 2>/dev/null); then
            grim -g "$area" "$temp_file"
            copy_and_save "$temp_file" "$final_file" "taken (area)"
        else
            notify-send "Screenshot Cancelled" "Area selection was cancelled" \
                --icon="dialog-information" \
                --urgency=low
            exit 0
        fi
        ;;
        
    "window")
        temp_file="$TEMP_DIR/screenshot_$DATE.png"
        final_file="$SCREENSHOT_DIR/window_$DATE.png"
        
        # Get the focused window
        if window=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' 2>/dev/null); then
            if [[ "$window" != "null null nullxnull" ]]; then
                grim -g "$window" "$temp_file"
                copy_and_save "$temp_file" "$final_file" "taken (window)"
            else
                notify-send "Screenshot Failed" "No active window found" \
                    --icon="dialog-error" \
                    --urgency=normal
                exit 1
            fi
        else
            notify-send "Screenshot Failed" "Could not get window information" \
                --icon="dialog-error" \
                --urgency=normal
            exit 1
        fi
        ;;
        
    "monitor")
        monitor_name="${2:-$(hyprctl monitors -j | jq -r '.[0].name')}"
        temp_file="$TEMP_DIR/screenshot_$DATE.png"
        final_file="$SCREENSHOT_DIR/monitor_${monitor_name}_$DATE.png"
        
        grim -o "$monitor_name" "$temp_file"
        copy_and_save "$temp_file" "$final_file" "taken (monitor: $monitor_name)"
        ;;
        
    "edit-area")
        temp_file="$TEMP_DIR/screenshot_$DATE.png"
        final_file="$SCREENSHOT_DIR/edited_$DATE.png"
        
        if area=$(slurp 2>/dev/null); then
            grim -g "$area" "$temp_file"
            if [[ -f "$temp_file" ]]; then
                wl-copy < "$temp_file"
                edit_screenshot "$temp_file"
                mv "$temp_file" "$final_file"
                notify_screenshot "$final_file" "edited and saved"
            fi
        else
            notify-send "Screenshot Cancelled" "Area selection was cancelled" \
                --icon="dialog-information" \
                --urgency=low
            exit 0
        fi
        ;;
        
    "clipboard-only")
        temp_file="$TEMP_DIR/screenshot_clipboard_$DATE.png"
        
        if [[ "$2" == "area" ]]; then
            if area=$(slurp 2>/dev/null); then
                grim -g "$area" "$temp_file"
                wl-copy < "$temp_file"
                rm "$temp_file"
                notify-send "Screenshot Copied" "Area screenshot copied to clipboard" \
                    --icon="edit-copy" \
                    --urgency=low
            fi
        else
            grim "$temp_file"
            wl-copy < "$temp_file"
            rm "$temp_file"
            notify-send "Screenshot Copied" "Fullscreen screenshot copied to clipboard" \
                --icon="edit-copy" \
                --urgency=low
        fi
        ;;
        
    "delay")
        delay_time="${2:-3}"
        temp_file="$TEMP_DIR/screenshot_$DATE.png"
        final_file="$SCREENSHOT_DIR/delayed_$DATE.png"
        
        notify-send "Screenshot in ${delay_time}s" "Preparing to take screenshot..." \
            --icon="camera-photo" \
            --urgency=low \
            --expire-time=1000
            
        sleep "$delay_time"
        grim "$temp_file"
        copy_and_save "$temp_file" "$final_file" "taken (delayed)"
        ;;
        
    "interactive")
        choice=$(echo -e "Fullscreen\nArea\nWindow\nMonitor\nEdit Area\nClipboard Only\nDelay 3s\nDelay 5s" | \
                wofi --dmenu --prompt "Screenshot:" --height=300)
        
        case "$choice" in
            "Fullscreen") exec "$0" fullscreen ;;
            "Area") exec "$0" area ;;
            "Window") exec "$0" window ;;
            "Monitor") exec "$0" monitor ;;
            "Edit Area") exec "$0" edit-area ;;
            "Clipboard Only") exec "$0" clipboard-only area ;;
            "Delay 3s") exec "$0" delay 3 ;;
            "Delay 5s") exec "$0" delay 5 ;;
            *) exit 0 ;;
        esac
        ;;
        
    *)
        echo "Usage: $0 {fullscreen|area|window|monitor|edit-area|clipboard-only|delay|interactive}"
        echo ""
        echo "Commands:"
        echo "  fullscreen     - Capture entire screen"
        echo "  area          - Select area to capture"
        echo "  window        - Capture active window"
        echo "  monitor [name] - Capture specific monitor"
        echo "  edit-area     - Select area and edit before saving"
        echo "  clipboard-only [area] - Copy to clipboard only"
        echo "  delay [seconds] - Delayed screenshot (default 3s)"
        echo "  interactive   - Show menu to choose option"
        exit 1
        ;;
esac
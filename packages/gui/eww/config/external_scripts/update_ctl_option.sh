#!/bin/bash

options=(poweroff reboot lock logout suspend hibernate)

current=$(eww get ctl_option)

find_index() {
    for i in "${!options[@]}"; do
        [[ "${options[$i]}" == "$1" ]] && echo "$i" && return
    done
    echo "-1"
}

if [[ "$current" == "" ]]; then
    eww update ctl_option="${options[0]}"
fi

index=$(find_index "$current")

if [[ "$1" == "left" ]]; then
    index=$(((index - 1 + ${#options[@]}) % ${#options[@]}))
    eww update ctl_option="${options[$index]}"

elif [[ "$1" == "right" ]]; then
    index=$(((index + 1) % ${#options[@]}))
    eww update ctl_option="${options[$index]}"

elif [[ "$1" == "return" ]]; then
    echo 0 >"/tmp/eww_monitor_panel_trigger/$$"

    case "$current" in
    poweroff) systemctl poweroff ;;
    reboot) systemctl reboot ;;
    lock) hyprlock ;;
    logout) loginctl terminate-user "$USER" ;;
    suspend) systemctl suspend ;;
    hibernate) systemctl hibernate ;;
    esac

elif [[ "$1" == "esc" ]]; then
    echo 0 >"/tmp/eww_monitor_panel_trigger/$$"
    eww update ctl_option=

elif [[ "$1" == "none" ]]; then
    if [[ $(eww get monitor_panel_open) == "false" ]]; then
        eww update monitor_panel_open=true
    fi

    echo 999999 >"/tmp/eww_monitor_panel_trigger/$$"
fi

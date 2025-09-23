#!/bin/bash

if [[ $# -eq 0 ]]; then
    eww update wifi_password="$(cat)"
    exit 0
fi

case "$1" in
"open")
    hyprctl dispatch submap wifi_panel_password

    eww update input_execute_script="$(basename "${BASH_SOURCE[0]}")"
    eww open input

    echo 999999 >"/tmp/eww_wifi_panel_trigger/$$"
    ;;
"return")
    hyprctl dispatch submap reset
    nmcli device wifi connect "$(eww get wifissid)" password "$(eww get wifi_password)"

    eww close input
    echo 0 >"/tmp/eww_wifi_panel_trigger/$$"

    eww update wifi_sub_panel_open=false wifi_password=
    ;;
"esc")
    hyprctl dispatch submap reset

    eww close input
    echo 0 >"/tmp/eww_wifi_panel_trigger/$$"

    eww update wifi_sub_panel_open=false wifi_password=
    ;;
esac

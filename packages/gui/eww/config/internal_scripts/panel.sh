#!/bin/bash

declare -A panel_groups=(
    ["launcher"]="left"
    ["wallpaper"]="center"
    ["clipboard"]="center"
    ["info"]="center"
    ["wifi"]="right"
    ["monitor"]="right"
)

panel_name="$1"
action="$2"

current_group="${panel_groups[$panel_name]}"

check_group_keep_open() {
    for panel in "${!panel_groups[@]}"; do
        [[ "${panel_groups[$panel]}" == "$current_group" && "$panel" != "$panel_name" ]] || continue
        [[ $(eww get "${panel}_panel_keep_open") == "true" ]] || continue
        exit 0
    done
}

close_group_panels() {
    for panel in "${!panel_groups[@]}"; do
        [[ "${panel_groups[$panel]}" == "$current_group" && "$panel" != "$panel_name" ]] || continue
        [[ $(eww get "${panel}_panel_open") == "true" ]] || continue
        eww update "${panel}_panel_open=false" "${panel}_panel_close=true"
    done
}

if [[ $(eww get "${panel_name}_panel_open") == "false" ]]; then

    if [[ $(eww get "${panel_name}_panel_close") == "true" && "$action" == "hover" ]]; then
        exit 0
    fi

    check_group_keep_open
    close_group_panels

    eww update "${panel_name}_panel_open=true" "${panel_name}_panel_close=false"
else
    if [[ $(eww get "${panel_name}_panel_keep_open") == "true" ]]; then
        exit 0
    fi

    eww update "${panel_name}_panel_open=false" "${panel_name}_panel_close=true"
fi

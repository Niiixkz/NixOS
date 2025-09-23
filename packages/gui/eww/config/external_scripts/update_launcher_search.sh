#!/bin/bash

rotate_apps() {
    local direction="$1"
    local filtered_apps="$(eww get filtered_apps)"
    local filtered_apps_count=$(echo "$filtered_apps" | jq 'length')

    if [[ $filtered_apps_count -le 1 ]]; then
        return
    fi

    local rotated_filtered_apps
    if [[ "$direction" == "up" ]]; then
        rotated_filtered_apps=$(echo "$filtered_apps" | jq '.[1:] + [.[0]]')
    else
        rotated_filtered_apps=$(echo "$filtered_apps" | jq '[.[-1]] + .[:-1]')
    fi

    eww update filtered_apps="$rotated_filtered_apps"
}

if [[ $# -eq 0 ]]; then
    search_text=$(cat)
    apps="$(eww get apps)"
    select_app_name=$(echo "$(eww get filtered_apps)" | jq -r '.[0].name // ""')

    rotated_filtered_apps=$(echo "$apps" | jq --arg query "$search_text" --arg select_app "$select_app_name" '
        map(select(.name | ascii_downcase | contains($query | ascii_downcase)))
        | . as $filtered
        | ($filtered | map(.name) | index($select_app)) as $select_app_index
        | if ($select_app_index != null and $select_app_index > 0) 
          then $filtered[$select_app_index:] + $filtered[0:$select_app_index]
          else $filtered
          end
    ')

    eww update launcher_search_text="$search_text" filtered_apps="$rotated_filtered_apps"
    exit 0
fi

case "$1" in
"open")
    if [[ $(eww get launcher_panel_open) == "false" ]]; then
        eww update launcher_panel_open=true
        eww update filtered_apps="$(eww get apps)" launcher_search_text=
    fi

    hyprctl dispatch submap launcher_panel_search

    eww update input_execute_script="$(basename "${BASH_SOURCE[0]}")"
    eww open input
    echo 999999 >"/tmp/eww_launcher_panel_trigger/$$"
    ;;

"return")
    cmd=$(echo "$(eww get filtered_apps)" | jq -r '
        if .[0] != null then
            if .[0].terminal == "true" then
                "foot " + .[0].exec
            else
                .[0].exec
            end
        else
            ""
        end
    ')

    [[ -n "$cmd" ]] || exit 0
    $cmd &
    disown

    hyprctl dispatch submap reset

    eww close input
    echo 0 >"/tmp/eww_launcher_panel_trigger/$"
    ;;

"esc")
    hyprctl dispatch submap reset

    eww close input
    echo 0 >"/tmp/eww_launcher_panel_trigger/$$"
    ;;

"up")
    rotate_apps "up"
    ;;

"down")
    rotate_apps "down"
    ;;

esac

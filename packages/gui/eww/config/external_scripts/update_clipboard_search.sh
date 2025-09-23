#!/bin/bash

rotate_filtered_clips() {
    local direction="$1"
    local filtered_clips="$(eww get filtered_clips)"
    local filtered_clips_count=$(echo "$filtered_clips" | jq 'length')

    if [[ $filtered_clips_count -le 1 ]]; then
        return
    fi

    local rotated_filtered_clips
    if [[ "$direction" == "up" ]]; then
        rotated_filtered_clips=$(echo "$filtered_clips" | jq '.[1:] + [.[0]]')
    else
        rotated_filtered_clips=$(echo "$filtered_clips" | jq '[.[-1]] + .[:-1]')
    fi

    eww update filtered_clips="$rotated_filtered_clips"
}

if [[ $# -eq 0 ]]; then
    search_text=$(cat)
    clips="$(eww get clips)"
    select_clip_id=$(echo "$(eww get filtered_clips)" | jq -r '.[0].id // ""')

    rotated_filtered_clips=$(echo "$clips" | jq --arg query "$search_text" --arg select_clip_id "$select_clip_id" '
        map(select(.content | ascii_downcase | contains($query | ascii_downcase)))
        | . as $filtered
        | ($filtered | map(.conent) | index($select_clip_id)) as $select_clip_index
        | if ($select_clip_index != null and $select_clip_index > 0) 
          then $filtered[$select_clip_index:] + $filtered[0:$select_clip_index]
          else $filtered
          end
    ')

    eww update clipboard_search_text="$search_text" filtered_clips="$rotated_filtered_clips"
    exit 0
fi

case "$1" in
"open")
    if [[ $(eww get clipboard_panel_open) == "false" ]]; then
        eww update clipboard_panel_open=true
        eww update filtered_clips="$(eww get clips)" clipboard_search_text=
    fi

    hyprctl dispatch submap clipboard_panel_search

    eww update input_execute_script="$(basename "${BASH_SOURCE[0]}")"
    eww open input
    echo 999999 >"/tmp/eww_clipboard_panel_trigger/$$"
    ;;

"return")
    id=$(echo "$(eww get filtered_clips)" | jq -r '
        if .[0] != null then
            .[0].id
        else
            ""
        end
    ')

    cliphist decode ${id} | wl-copy

    hyprctl dispatch submap reset

    eww close input
    echo 0 >"/tmp/eww_clipboard_panel_trigger/$"
    ;;

"esc")
    hyprctl dispatch submap reset

    eww close input
    eww update filtered_clips=
    echo 0 >"/tmp/eww_clipboard_panel_trigger/$$"
    ;;

"up")
    rotate_filtered_clips "up"
    ;;

"down")
    rotate_filtered_clips "down"
    ;;

esac

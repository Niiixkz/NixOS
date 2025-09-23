#!/bin/bash

COVER="/tmp/album_cover_eww.png"
MUSIC_DIR="$HOME/Music"

previous=""

update_info() {
    IFS=$'\t' read -r title artist album \
        <<<"$(mpc --format '%title%\t%artist%\t%album%' current)"

    status=$(mpc status | awk 'NR==2 {print $1}')

    second_line=$(mpc | sed -n '2p')
    if [[ $second_line =~ ([0-9]+):([0-9]+)/([0-9]+):([0-9]+) ]]; then
        len_mins=${BASH_REMATCH[3]}
        len_secs=${BASH_REMATCH[4]}
        len_sec=$((10#$len_mins * 60 + 10#$len_secs))
        length_str=$(printf '%d:%02d' "$((10#$len_mins))" "$((10#$len_secs))")
    else
        len_sec=""
        length_str=""
    fi

    if [[ "$previous" != "$title $artist" ]]; then
        rm -f "$COVER"

        file="$MUSIC_DIR/$(mpc --format %file% current 2>/dev/null)"

        ffmpeg -loglevel quiet -y -i "$file" -an \
            -vf "scale='if(gt(iw,ih),-1,ih)':'if(gt(ih,iw),-1,iw)',pad='max(iw,ih)':'max(iw,ih)':(ow-iw)/2:(oh-ih)/2:color=0x00000000" \
            -update 1 "$COVER"

        if [ $? -ne 0 ] || [ ! -s "$COVER" ]; then
            cp "$HOME/.config/ncmpcpp/default_cover.png" "$COVER"
        fi
    fi

    previous="$title $artist"

    jq -n -c \
        --arg name "mpd" \
        --arg title "${title:-}" \
        --arg artist "${artist:-}" \
        --arg artUrl "$COVER" \
        --arg status "$status" \
        --arg length "$len_sec" \
        --arg lengthStr "$length_str" \
        '{
            name: $name,
            title: $title,
            artist: $artist,
            thumbnail: $artUrl,
            status: $status,
            length: $length,
            lengthStr: $lengthStr
        }'
}

# Initial run
update_info

# Then start listening for changes
mpc idleloop player | while read -r _; do
    update_info
done

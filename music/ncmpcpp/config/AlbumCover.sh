#!/bin/bash

get_term_pixels() {
    exec </dev/tty
    old_stty=$(stty -g)
    stty raw -echo min 0 time 5

    printf '\033[14t' >/dev/tty

    IFS=';' read -r -d t _ height width

    stty "$old_stty"
    echo "$width $height"
}
sleep 0.5
COVER="/tmp/album_cover.png"

read -r pix_width pix_height <<<"$(get_term_pixels)"

function add_cover {
    img2sixel "$COVER" -w "$pix_width" || echo "Failed to display cover image."
    printf '\0338'
}

if [ ! -f "$COVER" ]; then
    cp "$HOME/.config/ncmpcpp/default_cover.png" "$COVER" || {
        echo "Failed to copy default cover image."
        exit 1
    }

    chmod 777 "$COVER"
fi

clear
add_cover

while inotifywait -q -e close_write "$COVER"; do
    clear
    add_cover
done

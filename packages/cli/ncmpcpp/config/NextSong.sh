#!/bin/bash

COVER="/tmp/album_cover.png"
MUSIC_DIR="$HOME/Music"

file="$MUSIC_DIR/$(mpc --format %file% current 2>/dev/null)"

ffmpeg -loglevel quiet -y -i "$file" -an -vf "scale='if(gt(iw,ih),-1,ih)':'if(gt(ih,iw),-1,iw)',pad='max(iw,ih)':'max(iw,ih)':(ow-iw)/2:(oh-ih)/2:color=0x00000000" -update 1 "$COVER"

if [ $? -ne 0 ] || [ ! -s "$COVER" ]; then
    COVER="$HOME/.config/ncmpcpp/default_cover.png"
fi

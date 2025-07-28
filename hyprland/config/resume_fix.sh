#!/bin/bash

asusctl -k high
bash $HOME/.config/hypr/toggle_touchpad.sh init
hyprctl reload && sleep 1 && hyprctl reload

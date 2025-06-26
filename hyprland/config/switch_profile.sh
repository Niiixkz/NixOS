#!/bin/bash

asusctl profile -n

current=$(asusctl profile -p | grep -oE 'Quiet|Balanced|Performance')
notify-send "ASUS Profile Switched" "Now using: $current"

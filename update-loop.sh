#!/bin/bash

while true; do
  eww update volume=$(~/.config/eww/scripts/volume.sh)
  eww update wifi_status=$(~/.config/eww/scripts/wifi.sh)
  bjson="$("$HOME/.config/eww/scripts/battery.sh" | tr -d '\n')"
  eww update batt_json="$bjson" 
  eww update workspaces="$(~/.config/eww/scripts/workspaces.sh)"
  eww update time="$(date '+%H:%M')" date="$(date '+%A, %d %B %Y')"
  sleep 2
done

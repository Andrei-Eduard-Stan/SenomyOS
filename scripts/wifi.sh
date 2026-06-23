#!/bin/sh
nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes' | cut -d: -f2

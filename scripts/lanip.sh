#!/bin/bash
#
# lanip - Print the LAN URL and a scannable QR code below it.
#
# Takes an optional port:
#
#   lanip        => http://192.168.0.10
#   lanip 3000   => http://192.168.0.10:3000

lanip() {
  local ip url

  ip=$(hostname -I | awk '{print $1}')
  url="http://$ip${1:+:$1}"

  echo "$url"

  if command -v qrencode > /dev/null; then
    qrencode -t ANSIUTF8 "$url"
  fi
}

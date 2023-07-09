#!/usr/bin/env sh

set -u

convert_config() {
    local \
        etc='/etc/can/raycan' \
        cfg='/tmp/ray/config' \
        ;
  : \
 && mkdir -p "$cfg" \
 && sh -c "ls -1 ${etc}/*.yaml" \
        | xargs -I {} sh -c "yq -o=json eval \$0 > \"${cfg}/\$(basename \$0 .yaml).json\"" {} \
 && ls "$cfg" \
  ;
}

run_xray() {
    local \
        cfg='/tmp/ray/config' \
        ;
  : \
 && exec xray \
        -confdir "$cfg" \
  ;
}

dhcp() {
  : \
 && mkdir -p /var/can/dhcp \
 && ln -s /var/can/dhcp /var/lib/dhcp \
 && dhclient -4 -v \
 && ip -4 address show \
 && ip -4 route show \
 && dhclient -6 -v \
 && ip -6 address show \
 && ip -6 route show \
  ;
}

main() {
  : \
 && sleep 2 \
 && dhcp \
 && convert_config \
 && run_xray \
  ;
}

if [ 0 -lt $# ]
then ${@:1}
else main
fi

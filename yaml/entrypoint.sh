#!/usr/bin/env sh

set -u

convert_config() {
    local \
        etc='/etc/can' \
        cfg='/tmp/ray/config' \
        ;
  : \
 && mkdir -p "$cfg" \
 && find "${etc}/raycan" \
        -type f \( -iname \*.yaml -o -iname \*.yml \) \
        -exec sh -c \
            "yq -o=json eval \$0 > \"${cfg}/\$( basename \$0 | cut -d. -f1 ).json\"" {} \; \
 && ls "$cfg" \
  ;
}

run_xray() {
    local \
        cfg='/tmp/ray/config' \
        log='/var/can/raycan/log' \
        ;
  : \
 && mkdir -p "$log" \
 && exec xray \
        -confdir "$cfg" \
  ;
}


main() {
  : \
 && convert_config \
 && run_xray \
  ;
}

main

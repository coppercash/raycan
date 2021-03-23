#!/bin/sh

CFG_DIR="/etc/xray"
EXT_CFG_DIR="${CFG_DIR}/ext"

mkdir -p ${EXT_CFG_DIR} \
&& cd ${EXT_CFG_DIR} \
&& find "/etc/raycan" \
    -type f \( -iname \*.yaml -o -iname \*.yml \) \
    -exec sh -c \
        'yq --tojson eval $0 > `basename $0 | cut -d. -f1`.json' {} \; \
&& cd ~

xray -config "${CFG_DIR}/default.json" -confdir ${EXT_CFG_DIR}

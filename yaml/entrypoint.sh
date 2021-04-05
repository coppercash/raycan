#!/bin/sh

RAY_CFG_DIR="/etc/raycan" 
XRAY_CFG_DIR="/etc/xray"
XRAY_EXT_CFG_DIR="${XRAY_CFG_DIR}/ext"

function run_xray() {
    mkdir -p ${XRAY_EXT_CFG_DIR} \
    && cd ${XRAY_EXT_CFG_DIR} \
    && find ${RAY_CFG_DIR} \
        -type f \( -iname \*.yaml -o -iname \*.yml \) \
        -exec sh -c \
            'yq --tojson eval $0 > `basename $0 | cut -d. -f1`.json' {} \; \
    && cd ~ \
    && xray \
        -config "${XRAY_CFG_DIR}/default.json" \
        -confdir ${XRAY_EXT_CFG_DIR}
}

run_xray

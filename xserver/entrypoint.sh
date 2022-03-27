#!/bin/sh

RAY_CFG_DIR="/etc/raycan" 
XRAY_CFG_DIR="/etc/xray"
XRAY_EXT_CFG_DIR="${XRAY_CFG_DIR}/ext"
XRAY_CRT_DIR="/var/xray/cert"
NGX_CFG_DIR="/etc/nginx"
HTML_DIR="/var/html"
KEY_LENGTH=ec-256
ACME_HOME_DIR="/usr/local/bin/acmesh"
ACME_CFG_DIR="/etc/acmesh"
ACME_LOG_DIR="/var/log/acmesh"

while getopts t flag
do
    case "${flag}" in
        t) test_issuing=1;;
    esac
done

function run_nginx() {
    echo "events {}
    http {
      server {
        listen 80;
        server_name ${SERVER_NAME};
        root ${HTML_DIR};
      }
    }" \
    > "${NGX_CFG_DIR}/nginx.conf" \
    && nginx
}

function run_acmesh() {
    acme.sh --issue \
        -d ${SERVER_NAME} \
        -w ${HTML_DIR} \
        --nginx \
        --keylength ${KEY_LENGTH} \
        --home ${ACME_HOME_DIR} \
        --config-home ${ACME_CFG_DIR} \
        --log "${ACME_LOG_DIR}/issue.log"
    case $? in
        0);; # Certificate issuing succeeded
        2);; # Certfiicate has not been expired
        *) return 1;; # Other errors
    esac
    mkdir -p ${XRAY_CRT_DIR} \
    && acme.sh --install-cert \
        -d ${SERVER_NAME} \
        --ecc \
        --home ${ACME_HOME_DIR} \
        --config-home ${ACME_CFG_DIR} \
        --log "${ACME_LOG_DIR}/install-cert.log" \
        --key-file "${XRAY_CRT_DIR}/key.pem" \
        --fullchain-file "${XRAY_CRT_DIR}/cert.pem"
}

function run_xray() {
    mkdir -p ${XRAY_EXT_CFG_DIR} \
    && cd ${XRAY_EXT_CFG_DIR} \
    && find ${RAY_CFG_DIR} \
        -type f \( -iname \*.yaml -o -iname \*.yml \) \
        -exec sh -c \
            'yq -o=json eval $0 > `basename $0 | cut -d. -f1`.json' {} \; \
    && cd ~ \
    && xray \
        -config "${XRAY_CFG_DIR}/default.json" \
        -confdir ${XRAY_EXT_CFG_DIR}
}

if [ -z ${test_issuing+x} ]; then
    echo "Running with '${SERVER_NAME}' ...";
    run_nginx \
    && run_acmesh \
    && run_xray
else
    echo "Tesing issuing for '${SERVER_NAME}' ...";
    run_nginx \
    && acme.sh --issue \
        -d ${SERVER_NAME} \
        -w ${HTML_DIR} \
        --nginx \
        --keylength ${KEY_LENGTH} \
        --home ${ACME_HOME_DIR} \
        --config-home ${ACME_CFG_DIR} \
        --test \
        --debug 3 \
        --log "${ACME_LOG_DIR}/test.log"
fi

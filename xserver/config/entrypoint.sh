#!/usr/bin/env bash

# TODO:

set -u

declare -r VAR_DIR='/var/raycan'
declare -r RAY_CFG_DIR='/etc/raycan' 
declare -r XRAY_CFG_DIR='/etc/xray'
declare -r XRAY_EXT_CFG_DIR="${XRAY_CFG_DIR}/ext"
declare -r XRAY_CRT_DIR="${VAR_DIR}/xray/cert"
declare -r XRAY_LOG_DIR="${VAR_DIR}/xray/log"
declare -r NGX_CFG_DIR='/etc/nginx'
declare -r HTML_DIR='/var/html'
declare -r KEY_LENGTH='ec-256'
declare -r ACME_HOME_DIR='/usr/local/bin/acmesh'
declare -r ACME_CFG_DIR='/etc/acmesh'
declare -r ACME_LOG_DIR="${VAR_DIR}/acmesh/log"

function make_website() {
    local -r source='https://raw.githubusercontent.com/Metroxe/one-html-page-challenge/070f33d8a5073560e3f377c9594a15162072881b/entries/ping-pong.html'

    if [ -f "${HTML_DIR}/index.html" ]
    then
        return 0
    fi

    mkdir -p "$HTML_DIR" \
 && wget \
        "$source" \
        -O "${HTML_DIR}/index.html" \
 && echo "Website made." \
  ;
}

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
 && nginx \
 && echo "Nginx started." \
     ;
}

function acmesh_test() {
    mkdir -p "$ACME_LOG_DIR" \
 && acme.sh --issue \
        -d "$SERVER_NAME" \
        -w "$HTML_DIR" \
        --nginx \
        --keylength "$KEY_LENGTH" \
        --home "$ACME_HOME_DIR" \
        --config-home "$ACME_CFG_DIR" \
        --test \
        --debug 3 \
        --log "${ACME_LOG_DIR}/test.log" \
 && echo "ACME test passed." \
     ;
}

function acmesh_issue() {
    mkdir -p "$ACME_LOG_DIR" \
 && acme.sh --issue \
        -d "$SERVER_NAME" \
        -w "$HTML_DIR" \
        --nginx \
        --keylength "$KEY_LENGTH" \
        --home "$ACME_HOME_DIR" \
        --config-home "$ACME_CFG_DIR" \
        --log "${ACME_LOG_DIR}/issue.log" \
 && echo "ACME issued." \
  ;
    case $? in
        0) return 0;; # Certificate issuing succeeded
        2) return 0;; # Certfiicate has not been expired
        *) return 1;; # Other errors
    esac
}

function acmesh_install() {
    mkdir -p "$XRAY_CRT_DIR" \
 && acme.sh --install-cert \
        -d "$SERVER_NAME" \
        --ecc \
        --home "$ACME_HOME_DIR" \
        --config-home "$ACME_CFG_DIR" \
        --log "${ACME_LOG_DIR}/install-cert.log" \
        --key-file "${XRAY_CRT_DIR}/key.pem" \
        --fullchain-file "${XRAY_CRT_DIR}/cert.pem" \
 && echo "ACME installed." \
  ;
}

function run_xray() {
    mkdir -p "$XRAY_LOG_DIR" \
 && mkdir -p "$XRAY_EXT_CFG_DIR" \
 && cd "$XRAY_EXT_CFG_DIR" \
 && find "$RAY_CFG_DIR" \
        -type f \( -iname \*.yaml -o -iname \*.yml \) \
        -exec sh -c \
            'yq -o=json eval $0 > `basename $0 | cut -d. -f1`.json' {} \; \
 && cd ~ \
 && xray \
        -config "${XRAY_CFG_DIR}/default.json" \
        -confdir "$XRAY_EXT_CFG_DIR" \
  ;
}

function run_wireguard() {
    if [ ! -f /etc/wireguard/wg0.conf ]
    then
        return 0
    fi
    modprobe ip6table_raw \
 && wg-quick up wg0 \
 && echo "Wiregard up." \
  ;
}

function main() {
    echo "Running with '${SERVER_NAME}' ..." \
 && run_wireguard \
 && make_website \
 && run_nginx \
 && acmesh_test \
 && acmesh_issue \
 && acmesh_install \
 && run_xray \
  ;
}

main

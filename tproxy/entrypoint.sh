#!/bin/sh

# Host (route table main default via Container) ->
# Container (iptables --tproxy-mark REROUTE_FW_MK) ->
# Container (rule fwmark REROUTE_FW_MK dev lo) ->
# Ray:RAY_PORT (streamSettings.sockopt.mark: OUTGOING_FW_MK) ->
# Host (rule fwmark OUTGOING_FW_MK via Gateway) ->
# Internet / Proxy Server

RAY_CFG_DIR="/etc/raycan" 
RAY_PORT=5100
XRAY_CFG_DIR="/etc/xray"
XRAY_EXT_CFG_DIR="${XRAY_CFG_DIR}/ext"

REROUTE_FW_MK=0x1
RT_TABLE_NO=50

function ip_addr() {
    ip address show dev eth0 scope global \
        | grep "inet " \
        | cut -d " " -f6 \
        | cut -d "/" -f1
}

function brd_addr() {
    ip address show dev eth0 scope global \
        | grep "inet " \
        | cut -d " " -f8
}

function run_xray() {
    mkdir -p ${XRAY_EXT_CFG_DIR} \
    && cd ${XRAY_EXT_CFG_DIR} \
    && rm -rf ./* \
    && find ${RAY_CFG_DIR} \
        -type f \( -iname \*.yaml -o -iname \*.yml \) \
        -exec sh -c \
            'yq -o=json eval $0 > `basename $0 | cut -d. -f1`.json' {} \; \
    && cd ~ \
    && xray \
        -config "${XRAY_CFG_DIR}/default.json" \
        -confdir ${XRAY_EXT_CFG_DIR}
}

function setup_iptables() {
    echo "Setting up iptables with ip address '`ip_addr`' broadcast address '`brd_addr`' ..." \
     && iptables -t mangle -N RAY \
     && iptables -t mangle -A RAY \
            -d 255.255.255.255 \
            -j RETURN \
     && iptables -t mangle -A RAY \
            -d 224.0.0.0/24 \
            -j RETURN \
     && iptables -t mangle -A RAY \
            -d `brd_addr` \
            -j RETURN \
     && iptables -t mangle -A RAY \
            -d `ip_addr` \
            -j RETURN \
     && iptables -t mangle -A RAY \
            -j TPROXY \
            -p udp \
            --on-port ${RAY_PORT} \
            --tproxy-mark ${REROUTE_FW_MK} \
     && iptables -t mangle -A RAY \
            -j TPROXY \
            -p tcp \
            --on-port ${RAY_PORT} \
            --tproxy-mark ${REROUTE_FW_MK} \
     && iptables -t mangle -A PREROUTING -j RAY
}
# Self-skipping
# Packages targeting ip_addr are not t-proxied,
# mainly the tproxy packages from the proxy server, via the host, targeting the container.
# Given that only packages target ip_addr are routed into the container,
# we don't setup other rules to filter out
# packages target other addresses in LAN.
#
# UDP
# UDP packages not targeting ip_addr are t-proxied
# via Ray listening on RAY_PORT
# and are marked with REROUTE_FW_MK.
#
# TCP
# Same with the previous but for TCP.

function setup_routing() {
    echo "Setting up routing ..." \
     && ip rule add \
            fwmark ${REROUTE_FW_MK} \
            lookup ${RT_TABLE_NO} \
     && ip route add \
            local default \
            dev lo \
            table ${RT_TABLE_NO}
}
# Rule
# All packages marked REROUTE_FW_MK by firewall
# lookup table RT_TABLE_NO.
#
# Table
# All packages lookup table RT_TABLE_NO, by default,
# get re-routed to device local.
# If not re-routed, the packages cannot be received by Ray.

setup_iptables && setup_routing && run_xray

#!/bin/sh

# Clients: the hosts or containers use TProxy as gateway.
# TProxy: This container.
# Ray: v2ray (or xray).
# Host: The physical machine hosts this container.
# Gateway: The gateway shared by TProxy and Host.
#
# Data Flow:
# Clients (route table main default via TProxy) ->
# TProxy (iptables --tproxy-mark REROUTE_FW_MK) ->
# TProxy (ip rule fwmark REROUTE_FW_MK dev lo) ->
# Ray:RAY_PORT
# Gateway
# Internet / Proxy Server
#
# Host is not involved in the entire data-flow.
# Thus, it can use TProxy as gateway as well.

declare -r RAY_CFG_DIR='/etc/raycan' 
declare -r RAY_PORT=5100
declare -r XRAY_CFG_DIR='/etc/xray'
declare -r XRAY_EXT_CFG_DIR="${XRAY_CFG_DIR}/ext"

declare -r REROUTE_FW_MK=0x1
declare -r RT_TABLE_NO=50

function ip_addr() {
    ip address show dev eth0 scope global \
        | grep 'inet ' \
        | cut -d ' ' -f6 \
        | cut -d '/' -f1
}

function brd_addr() {
    ip address show dev eth0 scope global \
        | grep 'inet ' \
        | cut -d ' ' -f8
}

function run_xray() {
    mkdir -p "$XRAY_EXT_CFG_DIR" \
    && cd "$XRAY_EXT_CFG_DIR" \
    && rm -rf ./* \
    && find "$RAY_CFG_DIR" \
        -type f \( -iname \*.yaml -o -iname \*.yml \) \
        -exec sh -c \
            'yq -o=json eval $0 > `basename $0 | cut -d. -f1`.json' {} \; \
    && cd ~ \
    && xray \
        -config "${XRAY_CFG_DIR}/default.json" \
        -confdir "$XRAY_EXT_CFG_DIR"
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
            --on-port "$RAY_PORT" \
            --tproxy-mark "$REROUTE_FW_MK" \
     && iptables -t mangle -A RAY \
            -j TPROXY \
            -p tcp \
            --on-port "$RAY_PORT" \
            --tproxy-mark "$REROUTE_FW_MK" \
     && iptables -t mangle -A PREROUTING -j RAY
}
# Self-skipping
# Packages targeting ip_addr are not t-proxied,
# mainly the tproxy packages from the proxy server, via the host, targeting the container.
# Given that only packages targeting ip_addr are routed into the container,
# we don't need to setup other rules to filter out
# packages targeting other addresses in LAN.
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
            fwmark "$REROUTE_FW_MK" \
            lookup "$RT_TABLE_NO" \
     && ip route add \
            local default \
            dev lo \
            table "$RT_TABLE_NO"
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

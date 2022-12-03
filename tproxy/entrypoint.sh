#!/bin/sh

# TODO:
# * merge setup_iptables & setup_ip6tables

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

function convert_config() {
    find /etc/raycan \
        -type f \( -iname \*.yaml -o -iname \*.yml \) \
        -exec sh -c \
            'yq -o=json eval $0 > "/etc/xray/ext/$( basename $0 | cut -d. -f1 ).json"' {} \; \
    && ls /etc/xray/ext
}

function run_xray() {
    if [ -d "$RAY_CFG_DIR" ]; then
        convert_config
    fi
    xray \
        -config "${XRAY_CFG_DIR}/default.json" \
        -confdir "$XRAY_EXT_CFG_DIR"
}

function get_ip_addr() {
    ip address show dev eth0 \
        | grep "${1} " \
        | cut -d ' ' -f6 \
        | cut -d '/' -f1
}

function setup_iptables() {
    echo \
     && iptables -t mangle -N RAY \
     && iptables -t mangle -A RAY \
            -m pkttype \
            --pkt-type broadcast \
            -j RETURN \
     && iptables -t mangle -A RAY \
            -m pkttype \
            --pkt-type multicast \
            -j RETURN \
     && iptables -t mangle -A RAY \
            -d "$( get_ip_addr 'inet' )" \
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
     && iptables -t mangle -A PREROUTING -j RAY \
     && iptables -nvL RAY -t mangle
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

function setup_ip6tables() {
    echo \
     && ip6tables -t mangle -N RAY \
     && ip6tables -t mangle -A RAY \
            -m pkttype \
            --pkt-type broadcast \
            -j RETURN \
     && ip6tables -t mangle -A RAY \
            -m pkttype \
            --pkt-type multicast \
            -j RETURN \
     && ip6tables -t mangle -A RAY \
            -d "$( get_ip_addr 'inet6' )" \
            -j RETURN \
     && ip6tables -t mangle -A RAY \
            -j TPROXY \
            -p udp \
            --on-port "$RAY_PORT" \
            --tproxy-mark "$REROUTE_FW_MK" \
     && ip6tables -t mangle -A RAY \
            -j TPROXY \
            -p tcp \
            --on-port "$RAY_PORT" \
            --tproxy-mark "$REROUTE_FW_MK" \
     && ip6tables -t mangle -A PREROUTING -j RAY \
     && ip6tables -nvL RAY -t mangle
}

function setup_routing() {
    echo \
     && ip rule add \
            fwmark "$REROUTE_FW_MK" \
            lookup "$RT_TABLE_NO" \
     && ip route add \
            local default \
            dev lo \
            table "$RT_TABLE_NO" \
     && ip rule \
     && ip route show table "$RT_TABLE_NO"
}
# Rule
# All packages marked REROUTE_FW_MK by firewall
# lookup table RT_TABLE_NO.
#
# Table
# All packages lookup table RT_TABLE_NO, by default,
# get re-routed to device local.
# If not re-routed, the packages cannot be received by Ray.

setup_iptables && setup_ip6tables && setup_routing && run_xray

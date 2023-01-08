#!/usr/bin/env bash

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

set -u

declare -r RAY_CFG_DIR='/etc/raycan' 
declare -r RAY_PORT=5100
declare -r XRAY_CFG_DIR='/etc/xray'
declare -r XRAY_EXT_CFG_DIR="${XRAY_CFG_DIR}/ext"

declare -r REROUTE_FW_MK=0x1
declare -r RT_TABLE_NO=50

declare -r CHAIN='RAY'

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

function get_iptables_command() {
    local -r family=$1
    case "$family" in 
        4) echo 'iptables';;
        6) echo 'ip6tables';;
        *) echo ''
    esac
}

function setup_iptables() {
    local -r family=$1

    local -r iptables=$(get_iptables_command "$family")
    if [ -z "$iptables" ]
    then
        return 1
    fi

    (return 0) \
     && "$iptables" -t mangle -N "$CHAIN" \
     && "$iptables" -t mangle -A "$CHAIN" \
            -m pkttype \
            --pkt-type broadcast \
            -j RETURN \
     && "$iptables" -t mangle -A "$CHAIN" \
            -m pkttype \
            --pkt-type multicast \
            -j RETURN \
     && "$iptables" -t mangle -A "$CHAIN" \
            -m addrtype \
            --dst-type LOCAL \
            -j RETURN \
     && "$iptables" -t mangle -A "$CHAIN" \
            -j TPROXY \
            -p udp \
            --on-port "$RAY_PORT" \
            --tproxy-mark "$REROUTE_FW_MK" \
     && "$iptables" -t mangle -A "$CHAIN" \
            -j TPROXY \
            -p tcp \
            --on-port "$RAY_PORT" \
            --tproxy-mark "$REROUTE_FW_MK" \
     && "$iptables" -t mangle -A PREROUTING \
            -j "$CHAIN" \
     && "$iptables" -n -t mangle --list "$CHAIN" \
      ;
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

function teardown_iptables() {
    local -r family=$1

    local -r iptables=$(get_iptables_command "$family")
    if [ -z "$iptables" ]
    then
        return 1
    fi

    (return 0) \
     && ( \
            (   "$iptables" \
                    --table mangle \
                    -C PREROUTING \
                    -j "$CHAIN" \
                && "$iptables" \
                    --table mangle \
                    -D PREROUTING \
                    -j "$CHAIN" \
            ) \
         || return 0 \
        ) \
     && (   [ -z "$( "$iptables" \
                        --numeric \
                        --table mangle \
                        --list "$CHAIN" \
                        2>/dev/null \
                    )" ] \
         || (   "$iptables" \
                    --table mangle \
                    --flush "$CHAIN" \
             && "$iptables" \
                    --table mangle \
                    --delete-chain "$CHAIN" \
            ) \
        ) \
      ;
}

function setup_routing() {
    (return 0) \
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

function main() {
    (return 0) \
      && setup_iptables '4' \
      && setup_iptables '6' \
      && setup_routing \
      && run_xray \
       ;
}

function refresh_iptables() {
    (return 0) \
      && teardown_iptables "$1" \
      && setup_iptables "$1" \
       ;
}

if (($# < 1))
then
    main
else
    case "$1" in 
        refresh-iptables)
            refresh_iptables "$2"
            ;;
        *)
            echo "Unrecognized sub-command '${1}'." \
              && exit 1
    esac
fi

#!/usr/bin/env sh

set -u

# Clients: The hosts or containers use TProxy as gateway.
# TProxy: This container.
# Port: A local (mandatory) port the traffic gets forwarded to.
# Process: A process runs in user mode that proceeds the traffic.
#
# Data Flow:
# Clients (route table main default via TProxy) ->
# TProxy (iptables --tproxy-mark `REROUTE_FW_MK`) ->
# TProxy (ip rule fwmark `REROUTE_FW_MK` dev lo) ->
# Port ->
# Process ->

REROUTE_FW_MK='0x1'
RT_TABLE_NO='50'
CHAIN='TPRX'
PORT='50000'

iptables_command() {
    local family="$1"
    case "$family" in 
        4) echo 'iptables';;
        6) echo 'ip6tables';;
        *) echo ''
    esac
}

# TCP/UDP traffic not targeting address of TProxy
# but passing address of TProxy
# are t-proxied to `Port`
# and marked with `REROUTE_FW_MK`.
#
# Traffic targeting self.address are not t-proxied.
# E.g. DNS traffic.
# E.g. the traffic sent back by remote servers.
#
# Given that traffic targeting other hosts in LAN
# is routed by the gateway to them directly.
# There is no need to setup extra rules to filter them out.
#
setup_iptables() {
    local \
        iptables="$(iptables_command $1)" \
        tport="$PORT" \
        ;

  : \
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
        --on-port "$tport" \
        --tproxy-mark "$REROUTE_FW_MK" \
 && "$iptables" -t mangle -A "$CHAIN" \
        -j TPROXY \
        -p tcp \
        --on-port "$tport" \
        --tproxy-mark "$REROUTE_FW_MK" \
 && "$iptables" -t mangle -A PREROUTING \
        -j "$CHAIN" \
 && "$iptables" -n -t mangle --list "$CHAIN" \
  ;
}

teardown_iptables() {
    local \
        iptables="$(iptables_command $1)" \
        ;

  : \
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

# Rule
# All traffic marked `REROUTE_FW_MK` by firewall
# lookup table `RT_TABLE_NO`.
#
# Table
# All traffic lookup table `RT_TABLE_NO`, by default,
# get re-routed to device local.
# If not re-routed,
# the packets won't be received by Process.
#
setup_routing() {
 : \
 && ip rule add \
        fwmark "$REROUTE_FW_MK" \
        lookup "$RT_TABLE_NO" \
 && ip route add \
        local default \
        dev lo \
        table "$RT_TABLE_NO" \
 && ip rule \
 && ip route show table "$RT_TABLE_NO" \
  ;
}

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
 && setup_iptables '4' "$PORT" \
 && setup_iptables '6' "$PORT" \
 && setup_routing \
 && convert_config \
 && run_xray \
  ;
}

if ((0 < $#))
then ${@:1}
else main
fi

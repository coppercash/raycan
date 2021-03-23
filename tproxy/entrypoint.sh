#!/bin/sh

# Host (route table main default via Container) ->
# Container (iptables --tproxy-mark REROUTE_FW_MK) ->
# Container (rule fwmark REROUTE_FW_MK dev lo) ->
# Ray:RAY_PORT (streamSettings.sockopt.mark: OUTGOING_FW_MK) ->
# Host (rule fwmark OUTGOING_FW_MK via Gateway) ->
# Internet / Proxy Server

REROUTE_FW_MK=0x1
RT_TABLE_NO=50
RAY_PORT=5100
IPADDR=$(ip address show dev eth0 scope global | awk '/inet / {split($2,var,"/"); print var[1]}')

iptables -t mangle -N RAY
iptables -t mangle -A RAY \
    -d $IPADDR \
    -j RETURN
# Packages targeting IPADDR are not t-proxied,
# mainly the tproxy packages from the proxy server, via the host, targeting the container.
# Given that only packages target IPADDR are routed into the container,
# we don't setup other rules to filter out
# packages target other addresses in LAN.
iptables -t mangle -A RAY \
    -j TPROXY \
    -p udp \
    --on-port $RAY_PORT \
    --tproxy-mark $REROUTE_FW_MK
# UDP packages not targeting IPADDR are t-proxied
# via Ray listening on RAY_PORT
# and are marked with REROUTE_FW_MK.
iptables -t mangle -A RAY \
    -j TPROXY \
    -p tcp \
    --on-port $RAY_PORT \
    --tproxy-mark $REROUTE_FW_MK
# Same with the previous but for TCP.
iptables -t mangle -A PREROUTING -j RAY

ip rule add \
    fwmark $REROUTE_FW_MK \
    lookup $RT_TABLE_NO
# All packages marked REROUTE_FW_MK by firewall
# lookup table RT_TABLE_NO.
ip route add \
    local default \
    dev lo \
    table $RT_TABLE_NO
# All packages lookup table RT_TABLE_NO, by default,
# get re-routed to device local.
# If not re-routed, the packages cannot be received by Ray.

exec "/usr/local/share/xray" -config "/etc/xray/config.json"

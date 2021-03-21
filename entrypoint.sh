#!/bin/sh

FW_MARK=0x1
RT_TABLE_NO=50
RAY_PORT=5100
IPADDR=$(ip -f inet addr show eth0 | awk "/inet / {print $2}")

ip rule add \
    fwmark $FW_MARK \
    lookup $RT_TABLE_NO
# All packages marked FW_MARK by firewall
# lookup table RT_TABLE_NO.
ip route add \
    default \
    dev lo \
    table $RT_TABLE_NO
# All packages lookup table RT_TABLE_NO, by default,
# get re-routed to device local.

iptables -t mangle -N RAY
iptables -t mangle -A RAY \
    -d $IPADDR \
    -j RETURN
# Packages target IPADDR should not be proxied.
# Given that only packages target IPADDR are routed into the container,
# we don't setup other rules to filter out
# packages target other addresses in LAN.
iptables -t mangle -A RAY \
    -j TPROXY \
    -p udp \
    --on-port $RAY_PORT \
    --tproxy-mark $RT_TABLE_NO
iptables -t mangle -A RAY \
    -j TPROXY \
    -p tcp \
    --on-port $RAY_PORT \
    --tproxy-mark $RT_TABLE_NO
iptables -t mangle -A PREROUTING -j RAY

exec "/usr/local/share/xray" -config "/etc/xray/config.json"

FROM registry.access.redhat.com/ubi8/ubi-minimal
LABEL maintainer="Will <coderdreamer@gmail.com>"

ARG XRAY_FILE="/usr/local/bin/xray" \
    XRAY_DATA_DIR="/usr/local/share/xray" \
    ENTRYPOINT_FILE="/usr/local/bin/entrypoint.sh"

WORKDIR "/root"

COPY "./entrypoint.sh" $ENTRYPOINT_FILE

RUN chmod +x $ENTRYPOINT_FILE \
 && microdnf \
        --refresh \
        install iptables \
 && microdnf \
        clean all \
 && curl --location \
        "https://dl.lamp.sh/files/xray_linux_amd64" \
        --output $XRAY_FILE \
 && chmod +x $XRAY_FILE \
 && mkdir -p $XRAY_DATA_DIR \
 && curl --location \
        "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat" \
        --output $XRAY_DATA_DIR"/geosite.dat" \
 && curl --location \
        "https://github.com/v2fly/geoip/releases/latest/download/geoip.dat" \
        --output $XRAY_DATA_DIR"/geoip.dat"

VOLUME "/etc/xray"
ENTRYPOINT $ENTRYPOINT_FILE

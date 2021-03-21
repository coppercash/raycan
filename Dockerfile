FROM registry.access.redhat.com/ubi8/ubi-minimal
LABEL maintainer="Will <coderdreamer@gmail.com>"

WORKDIR /root
RUN microdnf \
        --refresh \
        install iptables \
 && microdnf \
        clean all \
 && curl --location \
        "https://dl.lamp.sh/files/xray_linux_amd64" \
        --output "/usr/bin/xray" \
 && chmod +x "/usr/bin/xray" \
 && mkdir -p /usr/local/share/xray \
 && curl --location \
        "https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat" \
        --output "/usr/local/share/xray/geosite.dat" \
 && curl --location \
        "https://github.com/v2fly/geoip/releases/latest/download/geoip.dat" \
        --output "/usr/local/share/xray/geoip.dat"

VOLUME /etc/xray
CMD [ "/usr/bin/xray", "-config", "/etc/xray/config.json" ]

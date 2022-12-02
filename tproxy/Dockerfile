FROM registry.access.redhat.com/ubi8/ubi-minimal
LABEL maintainer="Will <coderdreamer@gmail.com>"

ARG YQ_FILE="/usr/local/bin/yq"
ARG XRAY_FILE="/usr/local/bin/xray"
ARG XRAY_DATA_DIR="/usr/local/share/xray"
ARG XRAY_CFG_DIR="/etc/xray"
ARG XRAY_EXT_CFG_DIR="/etc/xray/ext"
ARG ENTRYPOINT_FILE="/usr/local/bin/entrypoint.sh"

RUN microdnf \
        --refresh install \
        iptables iproute iputils unzip findutils \
 && microdnf \
        clean all \
# Function to retrieve download URL.
 && GET_DOWNLOAD_URL() { \
        curl -L "https://api.github.com/repos/${1}/releases/latest" \
        | grep "browser_download_url" \
        | grep ${2} \
        | head -n 1 \
        | cut -d `printf "\x22"` -f 4 \
        ; \
    } \
# Install yq.
 && YQ_URL=$(GET_DOWNLOAD_URL "mikefarah/yq" "linux_amd64") \
 && echo "Downloading yq from ${YQ_URL} ..." \
 && curl --location \
        ${YQ_URL} \
        --output ${YQ_FILE} \
 && chmod +x ${YQ_FILE} \
 && echo "yq downloaded!" \
# Install xray.
 && XRAY_URL=$(GET_DOWNLOAD_URL "xtls/xray-core" "linux-64") \
 && echo "Downloading xray from ${XRAY_URL} ..." \
 && curl --location \
        ${XRAY_URL} \
        --output "/tmp/xray.zip" \
 && unzip "/tmp/xray.zip" -d "/tmp/xray" \
 && mv "/tmp/xray/xray" ${XRAY_FILE} \
 && mkdir -p ${XRAY_DATA_DIR} \
 && mv "/tmp/xray/geosite.dat" "${XRAY_DATA_DIR}/geosite.dat" \
 && mv "/tmp/xray/geoip.dat" "${XRAY_DATA_DIR}/geoip.dat" \
 && chmod +x ${XRAY_FILE} \
 && rm "/tmp/xray.zip" \
 && rm -r "/tmp/xray" \
 && echo "xray downloaded!"

COPY "./default.yml" "./entrypoint.sh" "/tmp/"
# Entrypoint
RUN mv "/tmp/entrypoint.sh" $ENTRYPOINT_FILE \
 && chmod +x $ENTRYPOINT_FILE \
# XRay Default Config
 && mkdir -p ${XRAY_CFG_DIR} \
 && mkdir -p ${XRAY_EXT_CFG_DIR} \
 && yq -o=json eval "/tmp/default.yml" > "${XRAY_CFG_DIR}/default.json" \
 && rm "/tmp/default.yml"

ENTRYPOINT "/usr/local/bin/entrypoint.sh"
# Don't know how to use variable with ENTRYPOINT.

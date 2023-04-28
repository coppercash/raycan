FROM registry.access.redhat.com/ubi9/ubi-minimal
LABEL maintainer="Will <coderdreamer@gmail.com>"

ARG PODTMP="/tmp/pod"

RUN echo \
 && microdnf \
        --assumeyes \
        --refresh install \
        iptables iproute iputils unzip findutils \
 && microdnf \
        clean all \
 && mkdir -p "$PODTMP" \
# Function to retrieve download URL.
 && github_url() { \
        curl --location "https://api.github.com/repos/${1}/releases/tags/${2}" \
        | grep "browser_download_url" \
        | grep "$3" \
        | head -n 1 \
        | cut -d `printf "\x22"` -f 4 \
        ; \
    } \
 && github_download() { \
        url=$(github_url "$1" "$2" "$4") \
        && echo "Downloading ${1}@${2} (arch ${4}) from ${url} ..." \
        && curl --location "$url" --output "$3" \
         ; \
    } \
 && github_download "mikefarah/yq" "v4.33.2" "${PODTMP}/yq" "linux_amd64" \
 && github_download "xtls/xray-core" "v1.7.5" "${PODTMP}/xray.zip" "linux-64" \
  ;

COPY \
    "./default.yml" \
    "./entrypoint.sh" \
    "${PODTMP}"

RUN echo \
# Install XRay.
 && unzip "${PODTMP}/xray.zip" -d "${PODTMP}/xray" \
 && chmod +x "${PODTMP}/xray/xray" \
 && mv "${PODTMP}/xray/xray" "/usr/local/bin/xray" \
 && mkdir -p "/usr/local/share/xray" \
 && mv -t "/usr/local/share/xray" \
        "${PODTMP}/xray/geosite.dat" \
        "${PODTMP}/xray/geoip.dat"  \
 && rm "${PODTMP}/xray.zip" \
 && rm -r "${PODTMP}/xray" \
# Install yq.
 && chmod +x "${PODTMP}/yq" \
 && mv "${PODTMP}/yq" "/usr/local/bin/yq" \
# XRay Default Config
 && mkdir -p "/etc/xray" \
 && yq -o=json eval "${PODTMP}/default.yml" > "/etc/xray/default.json" \
 && rm "${PODTMP}/default.yml" \
 && mkdir -p "/etc/xray/ext" \
 && mkdir -p "/var/log/xray" \
# Entrypoint
 && chmod +x "${PODTMP}/entrypoint.sh" \
 && mv "${PODTMP}/entrypoint.sh" "/usr/local/bin/entrypoint" \
# Clean up.
 && rm -r "$PODTMP" \
  ;

ENTRYPOINT ["entrypoint"]

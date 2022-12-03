FROM registry.access.redhat.com/ubi9/ubi-minimal
LABEL maintainer="Will <coderdreamer@gmail.com>"

ARG TMPDIR="/tmp/pod"

RUN echo \
 && microdnf \
        --assumeyes \
        --refresh install \
        iptables iproute iputils unzip findutils \
 && microdnf \
        clean all \
 && mkdir -p "$TMPDIR" \
# Function to retrieve download URL.
 && get_download_url() { \
        curl -L "https://api.github.com/repos/${1}/releases/latest" \
        | grep "browser_download_url" \
        | grep "${2}" \
        | head -n 1 \
        | cut -d $( printf "\x22" ) -f 4 \
        ; \
    } \
# Function to download from github.
 && download() { \
        src="$( get_download_url "$1" "$2" )" \
        && echo "Downloading ${1} from ${src} to ${3} ..." \
        && curl --location \
            "$src" \
            --output "$3" \
        ; \
    } \
 && download "mikefarah/yq" "linux_amd64" "${TMPDIR}/yq" \
 && download "xtls/xray-core" "linux-64" "${TMPDIR}/xray.zip" \
 && echo

COPY \
    "./default.yml" \
    "./entrypoint.sh" \
    "${TMPDIR}"

RUN echo \
# Install XRay.
 && unzip "${TMPDIR}/xray.zip" -d "${TMPDIR}/xray" \
 && chmod +x "${TMPDIR}/xray/xray" \
 && mv "${TMPDIR}/xray/xray" "/usr/local/bin/xray" \
 && mkdir -p "/usr/local/share/xray" \
 && mv -t "/usr/local/share/xray" \
        "${TMPDIR}/xray/geosite.dat" \
        "${TMPDIR}/xray/geoip.dat"  \
 && rm "${TMPDIR}/xray.zip" \
 && rm -r "${TMPDIR}/xray" \
# Install yq.
 && chmod +x "${TMPDIR}/yq" \
 && mv "${TMPDIR}/yq" "/usr/local/bin/yq" \
# XRay Default Config
 && mkdir -p "/etc/xray" \
 && yq -o=json eval "${TMPDIR}/default.yml" > "/etc/xray/default.json" \
 && rm "${TMPDIR}/default.yml" \
 && mkdir -p "/etc/xray/ext" \
 && mkdir -p "/var/log/xray" \
# Entrypoint
 && chmod +x "${TMPDIR}/entrypoint.sh" \
 && mv "${TMPDIR}/entrypoint.sh" "/usr/local/bin/entrypoint" \
# Clean up.
 && rm -r "$TMPDIR" \
 && echo

ENTRYPOINT ["entrypoint"]

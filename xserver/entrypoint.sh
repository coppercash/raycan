#!/bin/sh

RAY_CFG_DIR="/etc/xray"
RAY_EXT_CFG_DIR="${RAY_CFG_DIR}/ext"
NGX_CFG_DIR="/etc/nginx"
HTML_DIR="${NGX_CFG_DIR}/html"
CRT_DIR="/var/xray/crt"

mkdir -p ${RAY_EXT_CFG_DIR} \
&& cd ${RAY_EXT_CFG_DIR} \
&& find "/etc/raycan" \
    -type f \( -iname \*.yaml -o -iname \*.yml \) \
    -exec sh -c \
        'yq --tojson eval $0 > `basename $0 | cut -d. -f1`.json' {} \; \
&& cd ~ \
&& mkdir -p $HTML_DIR \
&& cd ${NGX_CFG_DIR} \
&& echo 'events {}\n\
http {\n\
  server {\n\
    listen 80;\n\
    server_name ${SERVER_NAME};\n\
    root ${HTML_DIR};\n\
  }\n\  
}'\
> "${NGX_CFG_DIR}/nginx.conf" \
&& echo '<html>\n\
  <head><title>${SERVER_NAME}</title></head>\n\
  <body><h1>Welcome to ${SERVER_NAME}!</h1></body>\n\
</html>'\
> "${HTML_DIR}/index.html" \
&& nginx \
&& acme.sh --issue \
    -d ${SERVER_NAME} \
    -w ${HTML_DIR} \
    --keylength ec-256 \
    --test \
&& acme.sh --install-cert \
    -d ${SERVER_NAME} \
    --ecc \
    --key-file "${CRT_DIR}/key.pem" \
    --fullchain-file "${CRT_DIR}/cert.pem" \
&& xray \
    -config "${RAY_CFG_DIR}/default.json" \
    -confdir ${RAY_EXT_CFG_DIR}

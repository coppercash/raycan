#!/usr/bin/env sh

set -ux

etc_dir() {
    echo '/etc/can'
}

var_dir() {
    echo '/var/can'
}

email() {
    echo "$EMAIL"
}

server_name() {
    echo "$SERVER_NAME"
}

key_length() {
    echo 'ec-256'
}

html_home_dir() {
    echo "$(var_dir)/html"
}

acmesh_home_dir() {
    echo '/usr/local/bin/acmesh'
}

acmesh_cfg_dir() {
    echo '/etc/acmesh'
}

acmesh_crt_dir() {
    echo "$(var_dir)/acmesh/cert"
}

acmesh_log_dir() {
    echo "$(var_dir)/acmesh/log"
}

ray_crt_dir() {
    echo "$(var_dir)/ray/cert"
}

ray_cfg_dir() {
    echo "/tmp/ray/config"
}

make_website() {
    local \
        repo='Metroxe/one-html-page-challenge' \
        version='070f33d8a5073560e3f377c9594a15162072881b' \
        path='entries/ping-pong.html' \
        ;
    local \
        source="https://raw.githubusercontent.com/${repo}/${version}/${path}" \
        ;

    if [ -f "$(html_home_dir)/index.html" ]
    then
        return 0
    fi

  : \
 && mkdir -p "$(html_home_dir)" \
 && wget \
        "$source" \
        -O "$(html_home_dir)/index.html" \
  ;
}

nginx_run() {
    local \
        cfg="/etc/nginx" \
        ;

  : \
 && echo "events {}
    http {
      server {
        listen 80;
        server_name $(server_name);
        root $(html_home_dir);
      }
    }" \
    > "${cfg}/nginx.conf" \
 && nginx \
  ;
}

acmesh_test() {
    local \
        crt_dir="$(acmesh_crt_dir)" \
        log_dir="$(acmesh_log_dir)" \
        ;

    if [ -d "$crt_dir" ] && [ ! -z "$(ls -A "$crt_dir")" ]
    then
        return 0
    fi

  : \
 && mkdir -p "$log_dir" \
 && acme.sh --issue \
        -d "$(server_name)" \
        -w "$(html_home_dir)" \
        --nginx \
        --keylength "$(key_length)" \
        --home "$(acmesh_home_dir)" \
        --config-home "$(acmesh_cfg_dir)" \
        --test \
        --log "${log_dir}/test.log" \
 && rm -rf "${crt_dir}/*" \
  ;
}

acmesh_register() {
    local \
        log_dir="$(acmesh_log_dir)" \
        ;
  : \
 && mkdir -p "$log_dir" \
 && acme.sh --register-account \
        -m "$(email)" \
        --server zerossl \
        --config-home "$(acmesh_cfg_dir)" \
        --debug 3 \
        --log "${log_dir}/test.log" \
  ;
}

acmesh_issue() {
    local \
        log_dir="$(acmesh_log_dir)" \
        ;

  : \
 && mkdir -p "$log_dir" \
 && acme.sh --issue \
        --server zerossl \
        -m "$(email)" \
        -d "$(server_name)" \
        -w "$(html_home_dir)" \
        --nginx \
        --keylength "$(key_length)" \
        --home "$(acmesh_home_dir)" \
        --config-home "$(acmesh_cfg_dir)" \
        --log "${log_dir}/issue.log" \
  ;
    case $? in
        0) return 0;; # Certificate issuing succeeded
        2) return 0;; # Certfiicate has not been expired
        *) return 1;; # Other errors
    esac
}

acmesh_install() {
    local \
        log_dir="$(acmesh_log_dir)" \
        dst="$(ray_crt_dir)" \
        ;

  : \
 && mkdir -p "$log_dir" \
 && mkdir -p "$dst" \
 && acme.sh --install-cert \
        -d "$(server_name)" \
        --ecc \
        --home "$(acmesh_home_dir)" \
        --config-home "$(acmesh_cfg_dir)" \
        --log "${log_dir}/install-cert.log" \
        --key-file "$(acmesh_crt_dir)/key.pem" \
        --fullchain-file "${dst}/cert.pem" \
  ;
}

ray_convert_config() {
    local \
        etc="$(etc_dir)/raycan" \
        cfg="$(ray_cfg_dir)" \
        ;
  : \
 && mkdir -p "$cfg" \
 && sh -c "ls -1 ${etc}/*.yaml" \
        | xargs -I {} sh -c "yq -o=json eval \$0 > \"${cfg}/\$(basename \$0 .yaml).json\"" {} \
 && ls "$cfg" \
  ;
}

ray_run() {
    local \
        cfg="$(ray_cfg_dir)" \
        log="$(var_dir)/ray/log" \
        ;
  : \
 && mkdir -p "$log" \
 && exec xray \
        -confdir "$cfg" \
  ;
}

test() {
  : \
 && make_website \
 && nginx_run \
 && acmesh_test \
  ;
}

main() {
  : \
 && make_website \
 && nginx_run \
 && acmesh_register \
 && acmesh_issue \
 && acmesh_install \
 && ray_convert_config \
 && ray_run \
  ;
}

test

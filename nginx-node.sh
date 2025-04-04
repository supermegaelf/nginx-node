#!/bin/bash

read -p "SNI domain: " SNI_DOMAIN

apt update && apt install curl gnupg2 ca-certificates lsb-release -y

curl -fsSL https://nginx.org/keys/nginx_signing.key | apt-key add -
echo "deb http://nginx.org/packages/ubuntu $(lsb_release -cs) nginx" > /etc/apt/sources.list.d/nginx.list

apt update && apt install nginx -y

mkdir -p /etc/nginx/snippets

cat > /etc/nginx/snippets/ssl.conf << EOF
ssl_certificate /etc/letsencrypt/live/$SNI_DOMAIN/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/$SNI_DOMAIN/privkey.pem;
EOF

cat > /etc/nginx/snippets/ssl-params.conf << EOF
ssl_session_timeout 1d;
ssl_session_cache shared:MozSSL:10m;
ssl_session_tickets off;

resolver 8.8.8.8 8.8.4.4;
resolver_timeout 5s;

ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305;
ssl_prefer_server_ciphers off;
EOF

rm -f /etc/nginx/conf.d/default.conf

cat > /etc/nginx/conf.d/sni-site.conf << EOF
server {
    server_name $SNI_DOMAIN;

    listen 8444 ssl proxy_protocol;
    http2 on;

    gzip on;

    location / {
        root /usr/share/nginx/html;
        index sni.html;
    }

    include /etc/nginx/snippets/ssl.conf;
    include /etc/nginx/snippets/ssl-params.conf;
}
EOF

wget -q https://raw.githubusercontent.com/supermegaelf/sni-page/main/sni.html -O /usr/share/nginx/html/sni.html

cat > /tmp/new_http_section << 'EOF'
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;

    keepalive_timeout  65;

    gzip on;
    gzip_disable "msie6";

    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_buffers 16 8k;
    gzip_http_version 1.1;
    gzip_min_length 256;
    gzip_types
      application/atom+xml
      application/geo+json
      application/javascript
      application/x-javascript
      application/json
      application/ld+json
      application/manifest+json
      application/rdf+xml
      application/rss+xml
      application/xhtml+xml
      application/xml
      font/eot
      font/otf
      font/ttf
      image/svg+xml
      text/css
      text/javascript
      text/plain
      text/xml;

    resolver 8.8.8.8 8.8.4.4;

    include /etc/nginx/conf.d/*.conf;
}
EOF

sed -i '/http {/,/}/d' /etc/nginx/nginx.conf
cat /tmp/new_http_section >> /etc/nginx/nginx.conf
rm -f /tmp/new_http_section

if nginx -t; then
    systemctl restart nginx
fi

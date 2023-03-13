### How to set up a vanity URL for Oracle APEX on Lightsail 

This solution uses a ~$3/month Lightsail instance with an NGINX reverse proxy and Let's Encrypt to establish a vanity URL for an Oracle APEX application.

https://www.youtube.com/watch?v=Pj--IAOipJU

I am assuming you have an AWS account and know how to log in.

These links may be helpful.

https://docs.bitnami.com/general/how-to/generate-install-lets-encrypt-ssl/

https://dgielis.blogspot.com/2019/09/free-oracle-cloud-7-setup-web-server-on.html

#### 1 - NGINX

Find Lightsail and create a new NGINX instance. 

#### 2 - Static IP

Once the new instance is up and running and attach a static IP address to your instance.

#### 3 - DNS

Update your domain DNS A records to point to the new static IP address.

#### 4 - Install Lego

Connect to the Lightsail instance and run the following commands.

```
cd /tmp
curl -Ls https://api.github.com/repos/xenolf/lego/releases/latest | grep browser_download_url | grep linux_amd64 | cut -d '"' -f 4 | wget -i -
tar xf lego_v*_linux_amd64.tar.gz
sudo mkdir -p /opt/bitnami/letsencrypt
sudo mv lego /opt/bitnami/letsencrypt/lego
cd $HOME
```

#### 5 - Let's Encrypt

```
export EMAIL="me@foo.com"
export DOMAIN="foo.com"
export WWW="www.foo.com"
sudo /opt/bitnami/ctlscript.sh stop nginx
sudo /opt/bitnami/letsencrypt/lego --tls --email="${EMAIL}" --domains="${DOMAIN}" --domains="${WWW}" --path="/opt/bitnami/letsencrypt" run
sudo /opt/bitnami/ctlscript.sh start nginx
```

#### 6 - Move certificates 


```
sudo mv /opt/bitnami/nginx/conf/bitnami/certs/server.crt /opt/bitnami/nginx/conf/bitnami/certs/server.crt.old
sudo mv /opt/bitnami/nginx/conf/bitnami/certs/server.key /opt/bitnami/nginx/conf/bitnami/certs/server.key.old
sudo mv /opt/bitnami/nginx/conf/bitnami/certs/server.csr /opt/bitnami/nginx/conf/bitnami/certs/server.csr.old
sudo ln -sf /opt/bitnami/letsencrypt/certificates/foo.com.key /opt/bitnami/nginx/conf/bitnami/certs/server.key
sudo ln -sf /opt/bitnami/letsencrypt/certificates/foo.com.crt /opt/bitnami/nginx/conf/bitnami/certs/server.crt
# One of commands below might throw an error. Everything should still work.
sudo chown root:root /opt/bitnami/nginx/conf/bitnami/certs/server*
sudo chmod 600 /opt/bitnami/nginx/conf/bitnami/certs/server*
```

### 7 - Edit NGINX config

```
cat /opt/bitnami/nginx/conf/nginx.conf

# Based on https://www.nginx.com/resources/wiki/start/topics/examples/full/#nginx-conf
user              daemon daemon;  ## Default: nobody

worker_processes  auto;
error_log         "/opt/bitnami/nginx/logs/error.log";
pid               "/opt/bitnami/nginx/tmp/nginx.pid";

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    log_format    main '$remote_addr - $remote_user [$time_local] '
                       '"$request" $status  $body_bytes_sent "$http_referer" '
                       '"$http_user_agent" "$http_x_forwarded_for"';
    access_log    "/opt/bitnami/nginx/logs/access.log" main;
    add_header    X-Frame-Options SAMEORIGIN;

    client_body_temp_path  "/opt/bitnami/nginx/tmp/client_body" 1 2;
    proxy_temp_path        "/opt/bitnami/nginx/tmp/proxy" 1 2;
    fastcgi_temp_path      "/opt/bitnami/nginx/tmp/fastcgi" 1 2;
    scgi_temp_path         "/opt/bitnami/nginx/tmp/scgi" 1 2;
    uwsgi_temp_path        "/opt/bitnami/nginx/tmp/uwsgi" 1 2;

    sendfile           on;
    tcp_nopush         on;
    tcp_nodelay        off;
    gzip               on;
    gzip_http_version  1.0;
    gzip_comp_level    2;
    gzip_proxied       any;
    gzip_types         text/plain text/css application/javascript text/xml application/xml+rss;
    keepalive_timeout  65;
    ssl_protocols      TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
    ssl_ciphers        HIGH:!aNULL:!MD5;
    client_max_body_size 80M;
    server_tokens off;

    absolute_redirect  on;
    port_in_redirect   on;

    include  "/opt/bitnami/nginx/conf/server_blocks/*.conf";

    # HTTP Server
    server {
        # Port to listen on, can also be set in IP:PORT format
        listen  80;
        return 301 https://$host$request_uri;
        include  "/opt/bitnami/nginx/conf/bitnami/*.conf";

        location /status {
            stub_status on;
            access_log   off;
            allow 127.0.0.1;
            deny all;
        }
    } 

    server {
        listen 443;
        server_name foo.com www.foo.com;

        location /ords/ {
            proxy_pass https://ny94ohpcjq4wdqy-foo.adb.us-phoenix-1.oraclecloudapps.com/ords/;
            proxy_set_header Origin "" ;
            proxy_set_header X-Forwarded-Host $host:$server_port;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_connect_timeout       600;
            proxy_send_timeout          600;
            proxy_read_timeout          600;
            send_timeout                600;
       }

       location /i/ {
           proxy_pass https://ny94ohpcjq4wdqy-foo.adb.us-phoenix-1.oraclecloudapps.com/i/;
           proxy_set_header X-Forwarded-Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       }
       
       location = / {
           return 301 /ords/r/app/foo/home ;
       }
    }
}

```

#### 8 - Restart NGINX

```
sudo /opt/bitnami/ctlscript.sh stop nginx
sudo /opt/bitnami/ctlscript.sh start nginx
```
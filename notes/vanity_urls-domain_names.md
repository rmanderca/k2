# Vanity URLS - Domain Names

## NGINX Reverse Proxy on Lightsail with MaxAPEX

[YouTube Video](https://youtu.be/1Sm_k2t6PkQ)
[MaxAPEX](https://clients.maxapex.com/aff.php?aff=137) (Affiliate link.)

* MaxAPEX hosting routes www.superloser.io to a specific APEX app running on my APEX instance.
* The APP ID needs to remain the same. So we can't just point to a new app, we need to replace the existing app when updating from dev.
* Create a NGINX Lightsail instance. 
* Click the link to get a static IP.
* Update your DNS records for your domain to point to the static IP.
* Get a terminal and update the /opt/bitnami/nginx/conf/nginx.conf file with an additional server block.

```
server {
   server_name superloser.io;
   return 301 https://www.superloser.io$request_uri;
}
```

* Follow these [instructions](https://docs.bitnami.com/general/how-to/generate-install-lets-encrypt-ssl/#alternative-approach).
* When I run the command below I do not include the www version of the domain.
```
sudo /opt/bitnami/letsencrypt/lego --tls --email="post.ethan@gmail.com" --domains="superloser.io" --path="/opt/bitnami/letsencrypt" run
```
* Enable snapshots for your Lightsail instance.
* Improvements can be made. Blocking http traffic directly to the IP or routing that to my domain.


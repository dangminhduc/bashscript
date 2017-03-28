First, edit gitlab.rb
```
#/etc/gitlab/gitlab.rb
nginx['enabled'] = true

gitlab_git_http_server['listen_network'] = "tcp"

gitlab_git_http_server['listen_addr'] = "localhost:8181"
```
then reconfigure gitlab
```
sudo gitlab-ctl reconfigure
```
edit nginx setting (may be not needed)
```
#/var/opt/gitlab/nginx/conf/gitlab-http.conf
upstream gitlab {
    server unix:/var/opt/gitlab/gitlab-rails/sockets/gitlab.socket;
}

upstream gitrepo {
    server localhost:8181;
}
.
.
.
location ~* \.(git) {
    proxy_read_timeout      300;
    proxy_connect_timeout   300;
    proxy_redirect          off;

    proxy_set_header   X-Forwarded-Proto $scheme;
    proxy_set_header   Host              $http_host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Frame-Options   SAMEORIGIN;
    proxy_pass http://gitrepo;
}
```
Then restart nginx
```
gitlab-ctl restart nginx
```


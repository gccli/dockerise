# Dockerize Nginx, MySQL and php-fpm

这里我们通过开发一个周报提交系统来演示如何将php应用docker化。

## 准备docker image

我们使用官方提供的nginx, mysql镜像，直接通过`docker pull`拉取即可。

```
# docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
nginx               latest              b8efb18f159b        2 weeks ago         107.5 MB
mysql               latest              c73c7527c03a        2 weeks ago         412.4 MB
```

### 构建php56w docker image

由于我们的php应用要求php版本为5.6，操作系统为Centos 7. 因此，对于php-fpm，我们使用webtatic.com源的php56w，需要自己创建，构建镜像的[Dockerfile](php56w/Dockerfile)如下：

```
FROM centos

RUN yum install -y epel-release && \
    rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm && \
    yum install -y php56w \
    php56w-common \
    php56w-fpm \
    php56w-pdo \
    php56w-mysql \
    php56w-gd \
    php56w-mbstring \
    php56w-mcrypt \
    php56w-xml

EXPOSE 9000
CMD ["php-fpm", "-F"]
```

Build php56w

    cd php56w
    docker build . -t php56w
    docker images

    $ docker images
    REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
    php56w              latest              ed1fc55cf222        47 hours ago        415 MB
    centos              latest              328edcd84f1b        9 days ago          192.5 MB
    nginx               latest              b8efb18f159b        2 weeks ago         107.5 MB
    mysql               latest              c73c7527c03a        2 weeks ago         412.4 MB


## Docker compose file

如下所示，compose file定义了3个服务，nginx, php-fpm, mysql

```
version: '2'
services:
  nginx:
    image: "nginx"
    links:
      - php-fpm
    ports:
      - "${EXTERNAL_PORT}:80"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./webapp/app:/opt/app
  php-fpm:
    build:
      context: webapp
    volumes:
      - ./webapp/app:/opt/app
    links:
      - mysql
  mysql:
    image: "mysql"
    volumes:
      - ./webapp/app/basic/sql:/sql
    environment:
      MYSQL_ALLOW_EMPTY_PASSWORD: "yes"
      MYSQL_DATABASE: "${MYSQL_DATABASE}"
```


### mysql service

环境变量`MYSQL_ALLOW_EMPTY_PASSWORD`使得将mysql root初始化密码设为空.  `MYSQL_DATABASE`表示创建初始数据库，来自`.env`文件中`MYSQL_DATABASE`的定义. mysql service将webapp/app/basic/sql目录挂载到/sql目录下，用于之后初始化应用的table，当mysql service开启，进入mysql service container，执行sql脚本初始化app所需的表.

    $ docker-compose exec mysql /bin/bash
    root@5fe2418ab277:/# msyql < /sql/worklog.sql

### nginx service

Nginx服务对外提供web service的reverse proxy的功能，其监听端口为`.env`文件中定义的`EXTERNAL_PORT`. 其应用配置文件[app.conf](nginx/conf.d/app.conf)定义如下：
```
server {
    charset utf-8;
    client_max_body_size 128M;
    listen 80;
    server_name localhost;
    root        /opt/app/basic/web;
    index       index.php;

    #access_log  /tmp/access.log;
    #error_log   /tmp/error.log;

    location / {
    # Redirect everything that isn't a real file to index.php
        try_files $uri $uri/ /index.php$is_args$args;
    }

    # deny accessing php files for the /assets directory
    location ~ ^/assets/.*\.php$ {
        deny all;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass php-fpm:9000;
        try_files $uri =404;
    }

    location ~* /\. {
        deny all;
    }
}
```

* `root`指定web app静态文件的目录`/opt/app/basic/web`, 通过Compose中的volume将webapp/app挂截到nginx service的/opt/app目录，使得nginx能够访问`root`指向的目录
* `fastcgi_pass`指向php-fpm服务的地址:`php-fpm:9000`，其中php-fpm为服务名。

### php-fpm服务

php-fpm service即真正php web app应用所在的服务，在php56w image的基础上将应用代码及配置文件部署其中，通过[Dockerfile](webapp/Dockerfile)描述：

php-fpm service在webapp目录下构建，其中app目录为web app的运行环境，包含以下目录

* basic - web app的代码，采用Yii 2 Basic Project Template
* logs - 日志所在的目录
* var - 运行时需要的目录，如cache, session等

```
FROM php56w

ADD app /opt/app
WORKDIR /opt/app

COPY php-fpm.conf       /etc/
COPY php-fpm.d/www.conf /etc/php-fpm.d/

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["php-fpm", "-F"]
```

以上Dockerfile将代码部署于新的image，并设定工作目录，并覆盖php-fpm的配置文件，实际上这几步完全可以不用做，通过docker compose file挂载即可。但`docker-entrypoint.sh`非常重要，在启php-fpm之前将会执行此脚本做一些初始化的动作，如修改目录权限等。

另外，将`webapp/app/basic/config/db.php`数据库的dsn修改为`'mysql:host=mysql;dbname=worklog'`，其中host指向mysql service的服务名。


## start service

在docker-compose.yml文件所在的目录执行

    docker-compose up --build

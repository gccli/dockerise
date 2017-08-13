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

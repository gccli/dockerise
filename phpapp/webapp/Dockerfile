FROM php56w

ADD app /opt/app
WORKDIR /opt/app

COPY php-fpm.conf       /etc/
COPY php-fpm.d/www.conf /etc/php-fpm.d/

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["php-fpm", "-F"]
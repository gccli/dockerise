#! /bin/bash

chown nobody.nobody -R /opt/app/var
chown nobody.nobody -R /opt/app/basic/web

echo "$@"
exec "$@"

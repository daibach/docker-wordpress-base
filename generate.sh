#!/bin/sh
set -xe

gen() {
  WORDPRESS=$1
  PHP=$2
  NAME=$3

  mkdir -p ${NAME}
  echo "FROM wordpress:${WORDPRESS}-php${PHP}-apache" > ${NAME}/Dockerfile
  echo '' >> ${NAME}/Dockerfile
  echo '# Setup wordpress installation location' >> ${NAME}/Dockerfile
  echo 'RUN mkdir -p /var/www/wordpress \' >> ${NAME}/Dockerfile
  echo '  && chown www-data:www-data /var/www/wordpress \' >> ${NAME}/Dockerfile
  echo '  && find /etc/apache2 -name '\''*.conf'\'' -type f -exec sed -ri -e '\''s!/var/www/html!/var/www/wordpress!g'\'' -e '\''s!Directory /var/www/!Directory /var/www/wordpress!g'\'' '\''{}'\'' +' >> ${NAME}/Dockerfile
  echo 'WORKDIR /var/www/wordpress' >> ${NAME}/Dockerfile
  echo 'ENV APACHE_DOCUMENT_ROOT /var/www/wordpress' >> ${NAME}/Dockerfile
  echo '' >> ${NAME}/Dockerfile
  echo '# Install dependencies and extensions' >> ${NAME}/Dockerfile
  echo 'RUN a2enmod rewrite' >> ${NAME}/Dockerfile
  echo '' >> ${NAME}/Dockerfile
  echo '# Harden php and apache' >> ${NAME}/Dockerfile
  echo 'RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"' >> ${NAME}/Dockerfile
  echo 'RUN { \' >> ${NAME}/Dockerfile
  echo '		echo 'ServerTokens Prod'; \' >> ${NAME}/Dockerfile
  echo '		echo 'ServerSignature Off'; \' >> ${NAME}/Dockerfile
  echo '    echo 'TraceEnable Off'; \' >> ${NAME}/Dockerfile
  echo '		echo 'Header always unset "X-Powered-By"'; \' >> ${NAME}/Dockerfile
  echo '    echo 'Header unset "X-Powered-By"'; \' >> ${NAME}/Dockerfile
  echo '  } | tee "$APACHE_CONFDIR/conf-available/docker-harden.conf" \' >> ${NAME}/Dockerfile
  echo '  && a2enmod headers \' >> ${NAME}/Dockerfile
  echo '  && a2disconf security \' >> ${NAME}/Dockerfile
  echo '	&& a2enconf docker-harden \' >> ${NAME}/Dockerfile
  echo '  && service apache2 restart' >> ${NAME}/Dockerfile
  echo 'RUN sed -i -e 's/expose_php=on/expose_php=off/g' "$PHP_INI_DIR/php.ini"' >> ${NAME}/Dockerfile
  echo '' >> ${NAME}/Dockerfile
}

gen 5.9 7.4 wp5.9-legacy
gen 5.9 8.0 wp5.9

gen 6.8 8.2 wp6.8
gen 6.8 8.4 wp6.8-php8.4

gen 6.9 8.4 wp6.9
gen 6.9 8.5 wp6.9-php8.5

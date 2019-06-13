FROM wordpress:5.2-php7.3-apache

# Setup wordpress installation location
RUN mkdir -p /var/www/wordpress \
  && chown www-data:www-data /var/www/wordpress \
  && find /etc/apache2 -name '*.conf' -type f -exec sed -ri -e 's!/var/www/html!/var/www/wordpress!g' -e 's!Directory /var/www/!Directory /var/www/wordpress!g' '{}' +
WORKDIR /var/www/wordpress
ENV APACHE_DOCUMENT_ROOT /var/www/wordpress

# Install dependencies and extensions
RUN a2enmod rewrite

# Harden php and apache
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
RUN { \
		echo ServerTokens Prod; \
		echo ServerSignature Off; \
    echo TraceEnable Off; \
		echo Header always unset X-Powered-By; \
    echo Header unset X-Powered-By; \
  } | tee "$APACHE_CONFDIR/conf-available/docker-harden.conf" \
  && a2enmod headers \
  && a2disconf security \
	&& a2enconf docker-harden \
  && service apache2 restart
RUN sed -i -e s/expose_php=on/expose_php=off/g "$PHP_INI_DIR/php.ini"


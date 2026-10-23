# syntax=docker/dockerfile:1
# cedyrn/wordpress-parent: the official WordPress image with the document root
# moved to /var/www/wordpress and Apache and PHP hardened.
ARG WORDPRESS_VERSION
ARG PHP_VERSION

FROM wordpress:${WORDPRESS_VERSION}-php${PHP_VERSION}-apache

# Setup wordpress installation location
RUN mkdir -p /var/www/wordpress \
  && chown www-data:www-data /var/www/wordpress \
  && find /etc/apache2 -name '*.conf' -type f -exec sed -ri -e 's!/var/www/html!/var/www/wordpress!g' -e 's!Directory /var/www/!Directory /var/www/wordpress!g' '{}' +
WORKDIR /var/www/wordpress
ENV APACHE_DOCUMENT_ROOT=/var/www/wordpress

# Install dependencies and extensions
RUN a2enmod rewrite

# Harden php and apache
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY rootfs/ /
RUN a2enmod headers \
  && a2disconf security \
	&& a2enconf docker-harden


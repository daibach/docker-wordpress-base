# syntax=docker/dockerfile:1
# check=skip=InvalidDefaultArgInFrom
# cedyrn/wordpress-parent: the official WordPress image with the document root
# moved to /var/www/wordpress and Apache and PHP hardened.

# No defaults: versions come only from versions.json, so a build without
# them fails rather than using a version set here.
ARG WORDPRESS_VERSION
ARG PHP_VERSION

FROM wordpress:${WORDPRESS_VERSION}-php${PHP_VERSION}-apache

# Serve WordPress from /var/www/wordpress rather than /var/www/html. The
# entrypoint copies WordPress into the working directory on first start.
ENV APACHE_DOCUMENT_ROOT=/var/www/wordpress
RUN mkdir -p /var/www/wordpress \
  && chown www-data:www-data /var/www/wordpress \
  && find /etc/apache2 -name '*.conf' -type f -exec sed -ri \
    -e 's!/var/www/html!/var/www/wordpress!g' \
    -e 's!Directory /var/www/!Directory /var/www/wordpress!g' '{}' +
WORKDIR /var/www/wordpress

# Production PHP settings, with the overrides in rootfs/ applied on top
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY rootfs/ /

# rewrite is enabled upstream already; enabling it here keeps permalinks
# working if that changes. headers is needed by docker-harden.conf.
RUN a2enmod rewrite headers \
  && a2disconf security \
  && a2enconf docker-harden

# Describes this build, for apps to report (e.g. in a health check endpoint).
# Last, so a new build date doesn't invalidate the cache of earlier layers.
ARG TARGETARCH
ARG BUILD_DATE
ARG BUILD_REVISION
ARG BUILD_URL
RUN set -eux; \
    mkdir -p /etc/wordpress-parent; \
    BUILD_DATE="${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}" php -r ' \
      $wp_version = (function () { \
        include "/usr/src/wordpress/wp-includes/version.php"; \
        return $wp_version; \
      })(); \
      echo json_encode([ \
        "image" => "cedyrn/wordpress-parent", \
        "wordpress_version" => $wp_version, \
        "php_version" => PHP_VERSION, \
        "debian_version" => trim(file_get_contents("/etc/debian_version")), \
        "architecture" => getenv("TARGETARCH"), \
        "built_at" => getenv("BUILD_DATE"), \
        "source_revision" => getenv("BUILD_REVISION") ?: null, \
        "build_url" => getenv("BUILD_URL") ?: null, \
      ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES), "\n";' > /etc/wordpress-parent/build.json; \
    cat /etc/wordpress-parent/build.json

#!/bin/sh
# Basic checks run against each image before it is pushed.
# Usage: tests/smoke-test.sh <image> [expected WordPress version] [expected PHP version]
# Versions match exactly or as a prefix: "7.1" matches 7.1.3, "8.4" matches 8.4.27.
set -eu

IMAGE=$1
EXPECTED_WP=${2:-}
EXPECTED_PHP=${3:-}
CONTAINER=wordpress-parent-smoke-$$
PORT=${SMOKE_PORT:-8080}
DOCROOT=/var/www/wordpress

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

run() {
  docker run --rm "$IMAGE" "$@"
}

# WordPress drops a trailing ".0" from its version (7.1.0 is "7.1")
version_matches() {
  actual=$1
  expected=$2
  case "$actual" in
    *.*.*) ;;
    *) actual="$actual.0" ;;
  esac
  case "$actual" in
    "$expected" | "$expected".*) return 0 ;;
    *) return 1 ;;
  esac
}

echo "== PHP version"
PHP_VERSION=$(run php -r 'echo PHP_VERSION;')
echo "$PHP_VERSION"
if [ -n "$EXPECTED_PHP" ]; then
  version_matches "$PHP_VERSION" "$EXPECTED_PHP" || fail "PHP $PHP_VERSION, expected $EXPECTED_PHP"
fi

echo "== WordPress version"
# shellcheck disable=SC2016 # $wp_version is PHP, not shell
WP_VERSION=$(run php -r 'include "/usr/src/wordpress/wp-includes/version.php"; echo $wp_version;')
echo "$WP_VERSION"
if [ -n "$EXPECTED_WP" ]; then
  version_matches "$WP_VERSION" "$EXPECTED_WP" || fail "WordPress $WP_VERSION, expected $EXPECTED_WP"
fi

echo "== PHP extensions"
MODULES=$(run php -m)
for ext in mysqli curl dom exif fileinfo gd imagick intl json mbstring openssl xml zip "Zend OPcache"; do
  echo "$MODULES" | grep -qix "$ext" || fail "extension $ext not loaded"
done

echo "== Composer"
run composer --version 2>/dev/null || fail "composer not working"

echo "== PHP config"
run php -i | grep -qx 'expose_php => Off => Off' || fail "expose_php is not Off"

echo "== Build info"
INFO=$(run cat /etc/wordpress-parent/build.json) || fail "build info missing"
echo "$INFO"
# shellcheck disable=SC2016 # $info and $wp_version are PHP, not shell
[ "$(run php -r '
  $info = json_decode(file_get_contents("/etc/wordpress-parent/build.json"), true);
  include "/usr/src/wordpress/wp-includes/version.php";
  echo $info["image"] === "cedyrn/wordpress-parent"
    && $info["wordpress_version"] === $wp_version
    && $info["php_version"] === PHP_VERSION
    && strtotime($info["built_at"]) ? "ok" : "bad";
')" = "ok" ] || fail "build info invalid"

echo "== Apache config"
run apache2ctl -t
docker run --rm --entrypoint grep "$IMAGE" -Eq "^\s*DocumentRoot $DOCROOT\s*$" \
  /etc/apache2/sites-enabled/000-default.conf || fail "document root is not $DOCROOT"

echo "== Apache serves PHP"
trap 'docker rm -f "$CONTAINER" >/dev/null 2>&1 || true' EXIT
docker run -d --name "$CONTAINER" -p "127.0.0.1:$PORT:80" "$IMAGE" >/dev/null
docker exec "$CONTAINER" sh -c "echo '<?php echo \"smoke-ok\";' > $DOCROOT/smoke.php"

for _ in $(seq 1 60); do
  curl -fsS -o /dev/null "http://127.0.0.1:$PORT/smoke.php" 2>/dev/null && break
  sleep 1
done

HEADERS=$(curl -fsS -D - -o /tmp/smoke-body-$$ "http://127.0.0.1:$PORT/smoke.php") \
  || { docker logs "$CONTAINER"; fail "no response from Apache"; }
BODY=$(cat /tmp/smoke-body-$$)
rm -f /tmp/smoke-body-$$

[ "$BODY" = "smoke-ok" ] || fail "unexpected body: $BODY"
echo "$HEADERS" | grep -qi '^x-powered-by:' && fail "X-Powered-By header present"
echo "$HEADERS" | grep -qi '^server: Apache[[:space:]]*$' || fail "Server header not minimal: $(echo "$HEADERS" | grep -i '^server:')"

echo "== Apache starts without warnings"
docker logs "$CONTAINER" 2>&1 | grep -q AH00558 && fail "Apache could not determine ServerName (AH00558)"

echo "== WordPress copied into the document root"
docker exec "$CONTAINER" test -f "$DOCROOT/wp-includes/version.php" || fail "WordPress not in $DOCROOT"

echo "PASS: $IMAGE"

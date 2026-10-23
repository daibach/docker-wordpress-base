#!/bin/sh
# Prints the images to build as a JSON matrix, from versions.json: one entry
# per WordPress and PHP version, tagged exactly (7.1.3-php8.4) and by minor
# version (7.1-php8.4), plus the frozen legacy aliases (-latest is PHP 8.4,
# -future is PHP 8.5). Used by build.yml and scan.yml.
set -eu

cd "$(dirname "$0")/../.."
jq -c '
  . as $v
  | [ $v.wordpress | to_entries[] as $wp
      | $v.php[] as $php
      | "\($wp.key)-php\($php)" as $name
      | { name: $name, wordpress: $wp.value, php: $php,
          tags: ( ["\($wp.value)-php\($php)", $name] + ($v.legacy_aliases[$name] // [])
                  | map("type=raw,value=\(.)") | join("\n") ) } ]
' versions.json

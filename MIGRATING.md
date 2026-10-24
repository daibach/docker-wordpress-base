# Moving apps off the legacy tags

The legacy tags are the names the images had before this repository built
them from `versions.json`:

| Legacy tag | State | Move to |
| --- | --- | --- |
| `latest`, `7.1-latest` | Updated, but frozen to WordPress 7.1 | `7.1.3-php8.4` |
| `7.1-future` | Updated, but frozen to WordPress 7.1 | `7.1.3-php8.5` |
| `7.0-latest` | No longer updated | `7.1.3-php8.4` (a WordPress upgrade) |
| `7.0-future` | No longer updated | `7.1.3-php8.5` (a WordPress upgrade) |
| `6.9-latest`, `6.8-latest` | No longer updated | `7.1.3-php8.4` (a WordPress upgrade) |

An image named with no tag (`FROM cedyrn/wordpress-parent`) is using
`latest`.

The tags in the "Move to" column are the current exact versions. Use the
newest one in the [README](README.md#tags) if it has moved on.

## Find the apps to change

```sh
grep -rnE 'cedyrn/wordpress-parent(:(latest|[0-9]+\.[0-9]+-(latest|future)))?([[:space:]"]|$)' ~/projects \
  --include='Dockerfile*' --include='*.yml' --include='*.yaml'
```

This finds the legacy tags and untagged references in Dockerfiles, Compose
files and CI workflows.

## Apps on `latest`, `7.1-latest` or `7.1-future`

These tags point at the same image as their replacement, so moving is only a
change of name. Change the `FROM` line:

```dockerfile
# Before
FROM cedyrn/wordpress-parent:7.1-latest

# After
FROM cedyrn/wordpress-parent:7.1.3-php8.4
```

Then rebuild and deploy the app as usual. Nothing in the image changes, so
there is nothing else to test.

Don't wait until the tag stops working: a legacy tag stops updating as soon as
WordPress 7.1 or its PHP version is dropped, and an app still using it would
then go without security fixes and no warning.

## Apps on `7.0-latest`, `7.0-future`, `6.9-latest` or `6.8-latest`

These images haven't been updated since their version was dropped, so they
are missing WordPress, PHP and Debian security fixes. Moving is a WordPress
upgrade, and needs the same care as any other:

1. Check that the app's plugins and themes support WordPress 7.1 and the PHP
   version you're moving to.
2. Change the `FROM` line to the new tag, rebuild, and test the app locally
   against a copy of its database.
3. Back up the production database.
4. Deploy. WordPress upgrades the database the first time someone opens
   `wp-admin`, or run `wp core update-db` if the app has WP-CLI.

If the app keeps `/var/www/wordpress` on a persistent volume, the new image
won't upgrade WordPress on its own. The entrypoint copies WordPress into the
document root only when it is empty, so the old WordPress files in the volume
stay. Either upgrade WordPress from `wp-admin` after deploying, or (better)
stop keeping WordPress itself on the volume and keep only `wp-content/uploads`
there.

## What's different from older legacy builds

An app that last pulled its legacy tag some time ago will get a slightly
different image when it rebuilds, whichever tag it uses:

- **Debian package updates** are installed when the image is built.
- **WordPress is pinned to an exact version** (`wordpress:7.1.3-php8.4-apache`)
  rather than upstream's moving `7.1` tag.
- **`expose_php` is off.** The legacy Dockerfile tried to turn it off but
  didn't, though Apache removed the `X-Powered-By` header anyway.
- **Apache's `ServerName` is set to `localhost`**, which stops the `AH00558`
  warning at start-up. An app that set `ServerName` only to silence that
  warning can drop it.
- **[`/etc/wordpress-parent/build.json`](README.md#build-info)** describes
  the build, for the app to report from its health check.
- **[Composer](README.md) and `unzip` are installed.** An app that builds its
  dependencies in a separate `composer` image can use the base image instead,
  and drop `--ignore-platform-reqs`.

None of these should need a change to the app.

## Pick the tag to use

Use the exact tag (`7.1.3-php8.4`) rather than the minor one (`7.1-php8.4`),
so the WordPress version only changes when the app changes it. Both tags get
Debian and PHP updates when the app rebuilds.

With an exact tag, the app has to change its `FROM` line for each WordPress
patch release, including security releases. If the app uses Renovate, it will
propose them (from `7.1.3-php8.4` to `7.1.4-php8.4`, keeping the PHP
version). Without Renovate, the minor tag picks them up on rebuild instead.

## Check the result

After rebuilding, check what the app is built on:

```sh
docker run --rm <app image> cat /etc/wordpress-parent/build.json
```

If the file is missing, the app is still on an image built before it was
added, which means it hasn't picked up the new base image.

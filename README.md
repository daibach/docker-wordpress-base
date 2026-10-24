# docker-wordpress-base

Base images for WordPress apps, published as
[`cedyrn/wordpress-parent`](https://hub.docker.com/r/cedyrn/wordpress-parent).

Each image is the official `wordpress:<version>-php<php>-apache` image with:

- the document root moved to `/var/www/wordpress`
- PHP's production settings (`php.ini-production`), with `expose_php` off
- Apache's version details and the `X-Powered-By` header hidden, and `TRACE`
  disabled
- the `rewrite` and `headers` Apache modules enabled
- Debian package updates installed at build time

Apps copy their plugins, themes and other files into `/usr/src/wordpress`. The
upstream entrypoint copies WordPress into the document root when the
container first starts.

```dockerfile
FROM cedyrn/wordpress-parent:7.1.3-php8.4
COPY wp-content/plugins /usr/src/wordpress/wp-content/plugins/
```

## Tags

| Tag | Example | Updates |
| --- | --- | --- |
| `<wordpress>-php<php>` | `7.1.3-php8.4` | Debian updates, and PHP patch releases when upstream ships them |
| `<wordpress minor>-php<php>` | `7.1-php8.4` | Also WordPress patch releases |

Use the exact tag (`7.1.3-php8.4`) in apps, so the WordPress version only
changes when the app changes it. Images are rebuilt weekly, so either tag
picks up those fixes when the app rebuilds.

Current builds:

| WordPress | PHP 8.4 | PHP 8.5 |
| --- | --- | --- |
| 7.1.3 | `7.1.3-php8.4`, `7.1-php8.4` | `7.1.3-php8.5`, `7.1-php8.5` |

### Legacy tags

These older names still point at the matching image, but are frozen to
WordPress 7.1: new WordPress versions won't get them, and each stops updating
when its WordPress or PHP version is dropped. Move apps to the tags above:
[`MIGRATING.md`](MIGRATING.md) explains how.

| Legacy tag | Same image as |
| --- | --- |
| `latest`, `7.1-latest` | `7.1-php8.4` |
| `7.1-future` | `7.1-php8.5` |

Tags for versions no longer built (such as `7.0.4-php8.4`, `7.0-latest`,
`7.0-future`, `6.9-latest` and `6.8-latest`) stay on Docker Hub without updates until they
are deleted.

## Build info

`/etc/wordpress-parent/build.json` describes the build of the image, and is
inherited by app images built from it:

```json
{
    "image": "cedyrn/wordpress-parent",
    "wordpress_version": "7.1.3",
    "php_version": "8.4.27",
    "debian_version": "13.7",
    "architecture": "amd64",
    "built_at": "2026-10-23T13:00:00Z",
    "source_revision": "a132607...",
    "build_url": "https://github.com/daibach/docker-wordpress-base/actions/runs/..."
}
```

The same tag is rebuilt weekly and for Debian updates, so `built_at` shows how
up to date an app's base image is better than the WordPress or PHP version
does. An app picks up a new base image only when it is rebuilt. Apps can
report it from their health check, for example in `healthcheck.php`:

```php
<?php
$base = json_decode((string) @file_get_contents('/etc/wordpress-parent/build.json'), true) ?: [];

header('Content-Type: application/json');
echo json_encode([
    'status' => 'ok',
    'base_image' => [
        'built_at' => $base['built_at'] ?? null,
        'age_days' => isset($base['built_at']) ? intdiv(time() - strtotime($base['built_at']), 86400) : null,
        'revision' => substr($base['source_revision'] ?? '', 0, 7) ?: null,
    ],
]);
```

Alerting on `age_days` (for example over 14) finds apps that haven't been
rebuilt since the base image was updated. The health check is usually public,
so leave version numbers out of it. `source_revision` and `build_url` are null
for local builds. Images built before this file was added don't have it.

## Versions

[`versions.json`](versions.json) lists what is built: the exact version of
each WordPress minor version, and the PHP minor versions. Every WordPress
version is built with every PHP version. The upstream image chooses the PHP
patch release.

```json
{
  "wordpress": {
    "7.1": "7.1.3"
  },
  "php": ["8.4", "8.5"],
  "legacy_aliases": {
    "7.1-php8.4": ["7.1-latest", "latest"],
    "7.1-php8.5": ["7.1-future"]
  }
}
```

To **add a WordPress version**, add a line such as `"7.2": "7.2.0"`. The
upstream `wordpress:7.2.0-php<php>-apache` tag must exist for every PHP
version listed.

To **add or drop a PHP version**, change the `php` list.

To **drop a version**, first check that no app uses it:

```sh
grep -r wordpress-parent ~/projects --include='Dockerfile*'
```

Removing a version stops it being rebuilt, but its tags stay on Docker Hub
without updates until they are deleted there.

**Drop a WordPress version once upstream stops building it.** Upstream only
rebuilds the newest WordPress minor version, so an older one stops getting
PHP patch releases (and its Debian packages fall further behind) as soon as
the next minor version is out. Check when upstream last pushed it:

```sh
curl -s https://hub.docker.com/v2/repositories/library/wordpress/tags/7.1.3-php8.4-apache | jq -r .tag_last_pushed
```

`legacy_aliases` maps a build to the legacy tags it also publishes. Don't add
to it.

### Updates

[Renovate](renovate.json) keeps `versions.json` and the GitHub Actions up to
date through pull requests:

- **WordPress patch releases** (7.1.3 to 7.1.4) are grouped into one PR and
  auto-merged once `Build result` passes. Each WordPress minor version gets
  its own patch updates.
- **New WordPress minor and major versions** are not proposed. Add them to
  `versions.json` by hand.
- **GitHub Actions** are pinned by commit SHA with the version in a comment.
  Minor, patch and digest updates are auto-merged.
- **Trivy** is downloaded by a pinned version and checksum. Renovate proposes
  new versions 3 days after release but doesn't merge them, because the
  checksum in [`setup-trivy`](.github/actions/setup-trivy/action.yml) has to be
  updated by hand in the same PR.

WordPress security releases are patch releases, so they reach these images
soon after upstream publishes them. Apps get them only when they rebuild.

Renovate usually has no release date for `wordpress` tags, because Docker Hub
only lists the newest 1,000 tags to anonymous clients. The config therefore
lets patch updates through without one (`timestamp-optional`) rather than
holding them forever. If a PR's build runs before upstream has published every
PHP variant, the build fails and nothing merges. Re-run the check later.

## Building and testing locally

```sh
docker build --platform linux/arm64 \
  --build-arg WORDPRESS_VERSION=7.1.3 --build-arg PHP_VERSION=8.4 \
  -t wordpress-parent:test .
tests/smoke-test.sh wordpress-parent:test 7.1.3 8.4
```

On Apple Silicon, build for `linux/arm64`. An amd64 image under emulation can
fail in ways that aren't real.

The smoke test checks the WordPress and PHP versions, the PHP extensions
WordPress needs, `expose_php`, the Apache config and document root, and that
a PHP page is served with no `X-Powered-By` header, a bare `Server: Apache`
header and no start-up warnings. The version arguments match exactly or as a
prefix (`8.4` matches `8.4.27`).

## Builds

[`.github/workflows/build.yml`](.github/workflows/build.yml) builds one image
per WordPress and PHP version in `versions.json`. It runs on pull requests,
on pushes to `main`, weekly (Mondays at 04:00 UTC, to pick up upstream PHP and
Debian updates), and by hand.

Each image is built for `linux/amd64` and pushed by digest only, with no tag.
That exact digest is pulled and smoke-tested, then tagged. Tags never point at
an untested image. A build that fails its tests leaves an untagged image on
Docker Hub, which does no harm. Pull requests build and test without pushing.
The `Build result` job passes only when every build passed, and is the
required check on `main`.

Published images carry [provenance](https://docs.docker.com/build/metadata/attestations/slsa-provenance/)
(`mode=max`: the base image, build arguments and source) and an
[SBOM](https://docs.docker.com/build/metadata/attestations/sbom/) of their
packages. To view them:

```sh
docker buildx imagetools inspect cedyrn/wordpress-parent:7.1.3-php8.4 --format '{{json .Provenance}}'
docker buildx imagetools inspect cedyrn/wordpress-parent:7.1.3-php8.4 --format '{{json .SBOM}}'
```

## Vulnerability scanning

[Trivy](https://trivy.dev) scans the images for Debian and other package
vulnerabilities that have a fix available:

- **Each build** scans every image after its smoke test and writes the HIGH
  and CRITICAL findings to the run's summary. Findings never fail the build.
- **[`scan.yml`](.github/workflows/scan.yml)** scans the published images
  (by their `<wordpress minor>-php<php>` tag) daily at 05:00 UTC, after every
  build of `main`, and by hand. It catches vulnerabilities disclosed after an
  image was built. Findings of every severity go to the repository's
  [Security tab](https://github.com/daibach/docker-wordpress-base/security/code-scanning),
  and close there once a rebuilt image no longer has them.

Most fixes reach the images through the weekly rebuild, which installs Debian
updates. For an urgent one, run the build by hand. Plugins and themes are
installed by the apps, so scan those in each app's build.

### Configuration

| Setting | Where |
| --- | --- |
| `DOCKERHUB_USERNAME` | Repository variable |
| `DOCKERHUB_TOKEN` | Repository secret: a Docker Hub access token with Read & Write scope |
| "Protect main" ruleset | No deletion or force push, pull request required, required check `Build result` |
| Renovate | The Mend Renovate GitHub app has access to this repo, set to Interactive mode on developer.mend.io |
| Allow auto-merge | Repository setting, needed for Renovate to auto-merge |

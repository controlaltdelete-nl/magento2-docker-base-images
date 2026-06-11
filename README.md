# Magento 2 Docker Base Images

All-in-one Docker images for Magento 2 CI/CD pipelines. Each image bundles PHP, MySQL, Elasticsearch, Redis, and Varnish so your pipeline only needs a single container.

## Available Tags

Images are published to GitHub Container Registry:

```
docker pull ghcr.io/controlaltdelete-nl/magento2-docker-base-images/magento2-base-image:<tag>
```

| PHP Version | Tags |
|-------------|------|
| 8.5 | `8.5`, `php85-fpm` |
| 8.4 | `8.4`, `php84-fpm` |
| 8.3 | `8.3`, `php83-fpm` |
| 8.2 | `8.2`, `php82-fpm` |
| 8.1 | `8.1`, `php81-fpm` |
| 7.4 | `7.4`, `php74-fpm` |
| 7.3 | `7.3`, `php73-fpm` |
| 7.2 | `7.2`, `php72-fpm` |
| 7.1 | `7.1`, `php71-fpm` |

## What's Included

- **PHP** (with FPM) and common Magento extensions (bcmath, gd, intl, mbstring, mysql, xml, zip, soap, xsl, etc.)
- **nginx** serving PHP through PHP-FPM (replaces the need for the PHP built-in dev server)
- **MySQL** with a pre-configured `magento` database and user
- **Elasticsearch 7.x** with ICU and phonetic analysis plugins
- **Redis**
- **Varnish**
- **Composer**
- **Node.js** (via nvm, default v20)
- **n98-magerun2**

## Usage

### In a CI pipeline (e.g. GitHub Actions)

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/controlaltdelete-nl/magento2-docker-base-images/magento2-base-image:8.4
    steps:
      - uses: actions/checkout@v4
      - run: ./start-services
      - run: composer install
      - run: bin/magento setup:install ...
```

### Running locally

```bash
docker run -it -v $(pwd):/data \
  michielgerritsen/magento2-base-image:8.4 \
  bash -c './start-services && bash'
```

## Services

All services are managed by Supervisord. Use the helper scripts in the container:

- `./start-services` — start MySQL, Elasticsearch, Redis, PHP-FPM, and nginx
- `./stop-services` — stop all services

Set `ENABLE_VARNISH=true` as an environment variable to also start Varnish.

## Web Server

nginx serves PHP through PHP-FPM and runs by default. The shipped config is a generic
front-controller (`try_files` to `index.php`, fastcgi to PHP-FPM on `127.0.0.1:9000`).

| Env var | Default | Effect |
|---------|---------|--------|
| `NGINX_DOCROOT` | `/data` | Document root nginx serves |
| `PHP_FPM_MAX_CHILDREN` | `4` | Caps PHP-FPM worker count (memory bounding) |
| `ENABLE_VARNISH` | unset | When `true`, Varnish takes `:80` and nginx moves to `:8080` behind it |

PHP-FPM runs an `ondemand` pool with a low `pm.max_children` so the image stays within
memory limits in CI (preventing OOM). Raise or lower it with `PHP_FPM_MAX_CHILDREN`.

### Magento downstream images

For a Magento app, activate the bundled wrapper that serves `pub/` via Magento's own
`nginx.conf.sample`:

```dockerfile
FROM ghcr.io/controlaltdelete-nl/magento2-docker-base-images/magento2-base-image:8.4
# Magento app lives at /data, with its nginx.conf.sample present
RUN cp /etc/nginx/available/magento.conf /etc/nginx/conf.d/default.conf
```

The base ships an `upstream fastcgi_backend` (which the Magento sample expects) and the
wrapper sets `$MAGE_ROOT`, `$MAGE_MODE`, and the multi-store run variables. Keep the
wrapper's literal `listen 80;` so the Varnish port-switch keeps working. This replaces the
older `php -S` dev server: drop the `php -S` Supervisord program and any custom
`0.0.0.0:80 -> :8080` sed in your entrypoint, since the base `start-services` now handles
the nginx port-switch when `ENABLE_VARNISH=true`.

## Pre-configured Databases

| Database | User | Password |
|----------|------|----------|
| `magento` | `magento` | `password` |
| `magento-test` | `magento-test` | `password` |

## Switching Node.js Versions

Node.js is installed via nvm. To use a different version:

```bash
. "$NVM_DIR/nvm.sh" && nvm install 18 && nvm use 18
```

## Exposed Ports

| Port | Service |
|------|---------|
| 9000 | PHP-FPM |
| 3306 | MySQL |
| 9200 | Elasticsearch |
| 6379 | Redis |
| 80 | nginx (Varnish when `ENABLE_VARNISH=true`, with nginx behind it on 8080) |

## Building Locally

```bash
docker build --build-arg PHP_VERSION=8.4 -t magento2-base-image:8.4 .
```

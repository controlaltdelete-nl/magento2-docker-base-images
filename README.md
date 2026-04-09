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

- `./start-services` — start MySQL, Elasticsearch, Redis, and PHP-FPM
- `./stop-services` — stop all services

Set `ENABLE_VARNISH=true` as an environment variable to also start Varnish.

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
| 80 | Varnish |
| 80 | HTTP |

## Building Locally

```bash
docker build --build-arg PHP_VERSION=8.4 -t magento2-base-image:8.4 .
```

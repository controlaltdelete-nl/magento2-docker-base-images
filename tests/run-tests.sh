#!/bin/bash

FAILURES=0

pass() {
  echo "  PASS: $1"
}

fail() {
  echo "  FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

assert() {
  local description="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    pass "$description"
  else
    fail "$description"
  fi
}

assert_contains() {
  local description="$1"
  local expected="$2"
  shift 2
  local actual
  actual=$("$@" 2>&1)
  if echo "$actual" | grep -q "$expected"; then
    pass "$description"
  else
    fail "$description (expected '$expected', got '$actual')"
  fi
}

curl_retry() {
  local url="$1"
  local attempt=0
  local body=""
  while [ "$attempt" -lt 15 ]; do
    body=$(curl -s "$url" 2>/dev/null)
    if [ "$body" != "" ]; then
      echo "$body"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 1
  done
  echo "$body"
  return 0
}

# ----------------------------------------------------------------
# PHP
# ----------------------------------------------------------------
echo "== PHP =="

if [ -n "$PHP_VERSION" ]; then
  assert_contains "PHP version matches $PHP_VERSION" "PHP $PHP_VERSION" php -v
fi

PHP_MODULES=$(php -m 2>/dev/null)
for ext in bcmath curl gd intl mbstring mysql xml zip soap ftp xsl sockets exif; do
  if echo "$PHP_MODULES" | grep -qi "$ext"; then
    pass "PHP extension: $ext"
  else
    fail "PHP extension: $ext"
  fi
done

if echo "$PHP_MODULES" | grep -qi "opcache\|Zend OPcache"; then
  pass "PHP extension: opcache"
else
  fail "PHP extension: opcache"
fi

# ----------------------------------------------------------------
# MySQL
# ----------------------------------------------------------------
echo "== MySQL =="

assert "MySQL responds" mysqladmin ping -u root
assert "Database 'magento' exists" mysql -u root -e "USE magento"
assert "Database 'magento-test' exists" mysql -u root -e "USE \`magento-test\`"
assert "User 'magento' can connect" mysql -u magento -ppassword -e "SELECT 1"
assert "User 'magento-test' can connect" mysql -u magento-test -ppassword -e "SELECT 1"

# ----------------------------------------------------------------
# Redis
# ----------------------------------------------------------------
echo "== Redis =="

assert_contains "Redis responds to PING" "PONG" redis-cli PING

# ----------------------------------------------------------------
# Elasticsearch
# ----------------------------------------------------------------
echo "== Elasticsearch =="

assert "Elasticsearch responds on port 9200" curl -sf http://localhost:9200
assert_contains "Elasticsearch ICU plugin installed" "analysis-icu" curl -sf http://localhost:9200/_cat/plugins
assert_contains "Elasticsearch phonetic plugin installed" "analysis-phonetic" curl -sf http://localhost:9200/_cat/plugins

# ----------------------------------------------------------------
# Composer
# ----------------------------------------------------------------
echo "== Composer =="

assert "Composer is installed" composer --version

# ----------------------------------------------------------------
# Node.js
# ----------------------------------------------------------------
echo "== Node.js =="

assert "Node.js is installed" node --version
assert_contains "Node.js major version is 20" "v20\." node --version
assert "nvm is installed" bash -c '. /usr/local/nvm/nvm.sh && nvm --version'
assert_contains "nvm can switch Node version" "v18\." bash -c '. /usr/local/nvm/nvm.sh && nvm install 18 --no-progress > /dev/null 2>&1 && node --version'

# ----------------------------------------------------------------
# Magerun
# ----------------------------------------------------------------
echo "== Magerun =="

assert "Magerun is installed" n98-magerun2 --version

# ----------------------------------------------------------------
# Mailpit
# ----------------------------------------------------------------
echo "== Mailpit =="

assert "it asserts the mailpit binary is installed and runnable" /usr/local/bin/mailpit version --no-release-check
assert_contains "it asserts the mailpit supervisord program is shipped with autostart false" "autostart=false" cat /etc/supervisor/conf.d/mailpit.conf

if [ "$ENABLE_MAILPIT" = "true" ]; then
  assert_contains "it asserts mailpit is RUNNING under supervisord when ENABLE_MAILPIT is true" "RUNNING" supervisorctl status mailpit
  assert "it asserts the mailpit api answers on port 8025 when enabled" curl -sf http://localhost:8025/readyz
  assert "it asserts the mailpit smtp port 1025 is listening when enabled" bash -c 'echo > /dev/tcp/127.0.0.1/1025'
  printf 'Subject: TDD Test\r\nFrom: sender@example.com\r\nTo: recipient@example.com\r\n\r\nTest body\r\n' \
    | /usr/local/bin/mailpit sendmail -S 127.0.0.1:1025 recipient@example.com > /dev/null 2>&1
  assert_contains "it asserts a message sent to the smtp port is retrievable via the rest api when enabled" \
    '"count":' curl_retry http://localhost:8025/api/v1/messages
  assert_contains "it asserts sendmail_path reported by php -i points at the mailpit shim when enabled" \
    "mailpit sendmail" php -i
else
  assert_contains "it asserts mailpit is not running and sendmail_path is unchanged when ENABLE_MAILPIT is unset" \
    "STOPPED" supervisorctl status mailpit
  assert_contains "it asserts mailpit is not running and sendmail_path is unchanged when ENABLE_MAILPIT is unset" \
    "/usr/sbin/sendmail" php -i
fi

# ----------------------------------------------------------------
# Varnish (only when enabled)
# ----------------------------------------------------------------
if [ "$ENABLE_VARNISH" = "true" ]; then
  echo "== Varnish =="
  assert_contains "Varnish is running" "RUNNING" supervisorctl status varnish
fi

# ----------------------------------------------------------------
# nginx
# ----------------------------------------------------------------
echo "== nginx =="

assert "nginx is installed" nginx -v
assert "nginx config is valid" nginx -t
assert_contains "nginx worker_processes is 1" "worker_processes 1" cat /etc/nginx/nginx.conf
assert "distro default nginx site is removed" bash -c '! test -e /etc/nginx/sites-enabled/default'
assert "nginx.conf does not include sites-enabled" bash -c '! grep -q sites-enabled /etc/nginx/nginx.conf'
assert_contains "nginx.conf includes conf.d" "include /etc/nginx/conf.d" cat /etc/nginx/nginx.conf
assert_contains "default site passes fastcgi to php-fpm on 9000" "127.0.0.1:9000" cat /etc/nginx/conf.d/default.conf
# shellcheck disable=SC2016
assert_contains "default site sets SCRIPT_FILENAME from document_root" 'SCRIPT_FILENAME $document_root' cat /etc/nginx/conf.d/default.conf
assert_contains "nginx runs under supervisord" "RUNNING" supervisorctl status nginx

# ----------------------------------------------------------------
# nginx: Magento downstream contract
# ----------------------------------------------------------------
echo "== nginx (Magento contract) =="

assert_contains "fastcgi_backend upstream is defined" "upstream fastcgi_backend" cat /etc/nginx/conf.d/fastcgi_backend.conf
assert_contains "fastcgi_backend targets 127.0.0.1:9000" "127.0.0.1:9000" cat /etc/nginx/conf.d/fastcgi_backend.conf
assert "fastcgi_backend lives in its own conf file" test -f /etc/nginx/conf.d/fastcgi_backend.conf
assert "Magento wrapper is shipped" test -f /etc/nginx/available/magento.conf
assert "Magento wrapper is inactive" bash -c '! test -e /etc/nginx/conf.d/magento.conf'
assert_contains "Magento wrapper has a literal listen 80" "listen 80" cat /etc/nginx/available/magento.conf
assert_contains "Magento wrapper sets MAGE_RUN_CODE" "MAGE_RUN_CODE" cat /etc/nginx/available/magento.conf
assert_contains "Magento wrapper sets MAGE_RUN_TYPE" "MAGE_RUN_TYPE" cat /etc/nginx/available/magento.conf
assert_contains "Magento wrapper includes nginx.conf.sample" "include /data/nginx.conf.sample" cat /etc/nginx/available/magento.conf

# ----------------------------------------------------------------
# php-fpm pool (memory bounding)
# ----------------------------------------------------------------
echo "== php-fpm pool =="

assert "stock www-data pool is removed" bash -c '! compgen -G "/etc/php/*/fpm/pool.d/www.conf"'
assert_contains "php-fpm pool user is root" "user = root" cat /etc/php/*/fpm/pool.d/zz-magento.conf
assert_contains "php-fpm pool group is root" "group = root" cat /etc/php/*/fpm/pool.d/zz-magento.conf
assert_contains "php-fpm is allowed to run as root (-R)" "\-R" cat /etc/supervisor/conf.d/php-fpm.conf
assert_contains "php-fpm pool listens on TCP 127.0.0.1:9000" "listen = 127.0.0.1:9000" cat /etc/php/*/fpm/pool.d/zz-magento.conf
assert_contains "php-fpm pool uses pm = ondemand" "pm = ondemand" cat /etc/php/*/fpm/pool.d/zz-magento.conf
assert_contains "php-fpm pool sets a process idle timeout" "pm.process_idle_timeout" cat /etc/php/*/fpm/pool.d/zz-magento.conf
assert_contains "php-fpm pool recycles workers via max_requests" "pm.max_requests = 500" cat /etc/php/*/fpm/pool.d/zz-magento.conf

if [ -n "$PHP_VERSION" ]; then
  assert "php-fpm config is valid" "/usr/sbin/php-fpm${PHP_VERSION}" -t
fi

if [ -z "$PHP_FPM_MAX_CHILDREN" ]; then
  assert_contains "php-fpm pm.max_children defaults to 4" "pm.max_children = 4" cat /etc/php/*/fpm/pool.d/zz-magento.conf
else
  assert_contains "php-fpm pm.max_children honors PHP_FPM_MAX_CHILDREN" "pm.max_children = $PHP_FPM_MAX_CHILDREN" cat /etc/php/*/fpm/pool.d/zz-magento.conf
fi

# ----------------------------------------------------------------
# HTTP serving (nginx -> php-fpm)
# ----------------------------------------------------------------
echo "== HTTP serving =="

SERVE_DOCROOT="${NGINX_DOCROOT:-/data}"
mkdir -p "$SERVE_DOCROOT"
echo '<?php echo "nginx-ok";' > "$SERVE_DOCROOT/index.php"

assert_contains "nginx serves PHP over HTTP on port 80" "nginx-ok" curl_retry http://localhost/
assert "php-fpm workers run as root" bash -c 'curl -s http://localhost/ > /dev/null; ps -eo user=,args= | grep "php-fpm: pool www" | grep -q "^root"'

if [ "$ENABLE_VARNISH" = "true" ]; then
  assert_contains "nginx listens on 8080 when Varnish is enabled" "listen 8080" cat /etc/nginx/conf.d/default.conf
fi

if [ -n "$NGINX_DOCROOT" ] && [ "$NGINX_DOCROOT" != "/data" ]; then
  assert_contains "nginx root is the custom NGINX_DOCROOT" "root ${NGINX_DOCROOT};" cat /etc/nginx/conf.d/default.conf
fi

assert "start-services reports the correct Varnish port (not 6081)" bash -c '! grep -q 6081 /data/start-services'

# ----------------------------------------------------------------
# CORS (opt-in via ENABLE_CORS)
# ----------------------------------------------------------------
echo "== CORS =="

assert "CORS snippet is shipped" test -f /etc/nginx/available/cors.conf
assert_contains "CORS snippet allows any origin" "Access-Control-Allow-Origin" cat /etc/nginx/available/cors.conf
assert "render-config is shipped" test -x /data/render-config

if [ "$ENABLE_CORS" = "true" ]; then
  assert_contains "responses carry Access-Control-Allow-Origin" "Access-Control-Allow-Origin: \*" curl -s -i http://localhost/
  assert "responses carry exactly one Access-Control-Allow-Origin header" \
    bash -c '[ "$(curl -s -i http://localhost/ | grep -c -i "access-control-allow-origin")" -eq 1 ]'
  assert_contains "preflight OPTIONS returns 204" "204" curl -s -o /dev/null -w "%{http_code}" -X OPTIONS http://localhost/
  assert_contains "preflight carries Access-Control-Allow-Methods" "Access-Control-Allow-Methods: \*" curl -s -i -X OPTIONS http://localhost/
  assert_contains "Magento wrapper includes the CORS snippet" "cors.conf" cat /etc/nginx/available/magento.conf
  assert "CORS snippet is included exactly once in the active config" \
    bash -c '[ "$(grep -c "cors.conf" /etc/nginx/conf.d/default.conf)" -eq 1 ]'
  assert "re-running render-config does not duplicate the CORS snippet" \
    bash -c '/data/render-config && [ "$(grep -c "cors.conf" /etc/nginx/conf.d/default.conf)" -eq 1 ] && [ "$(grep -c "cors.conf" /etc/nginx/available/magento.conf)" -eq 1 ]'
else
  assert "responses carry no CORS headers by default" bash -c '! curl -s -i http://localhost/ | grep -q Access-Control-Allow-Origin'
  assert "CORS snippet is inactive by default" bash -c '! grep -q cors.conf /etc/nginx/conf.d/default.conf'
fi

# ----------------------------------------------------------------
# Summary
# ----------------------------------------------------------------
echo ""
if [ $FAILURES -eq 0 ]; then
  echo "All tests passed."
else
  echo "$FAILURES test(s) FAILED."
  exit 1
fi

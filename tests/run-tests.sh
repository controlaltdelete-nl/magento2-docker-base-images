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

# ----------------------------------------------------------------
# Magerun
# ----------------------------------------------------------------
echo "== Magerun =="

assert "Magerun is installed" n98-magerun2 --version

# ----------------------------------------------------------------
# Varnish (only when enabled)
# ----------------------------------------------------------------
if [ "$ENABLE_VARNISH" = "true" ]; then
  echo "== Varnish =="
  assert_contains "Varnish is running" "RUNNING" supervisorctl status varnish
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

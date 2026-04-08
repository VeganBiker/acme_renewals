#!/bin/bash
set -euo pipefail

# ========= CONFIG =========
AW_HOST="hostname or ip"
AW_USER="user"
AW_PASS="password"

P12_PATH="/var/www/certs/cert.p12"
P12_PASSWORD="password"
# ==========================

echo "[AirWave] Base64-encoding PKCS#12..."
CERT_B64=$(base64 -w0 "$P12_PATH")


COOKIE_JAR="$(mktemp)"

LOGIN_HEADERS=$(curl -k -s -D - \
  -c "$COOKIE_JAR" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -X POST \
  "https://${AW_HOST}/LOGIN" \
  --data-urlencode "credential_0=${AW_USER}" \
  --data-urlencode "credential_1=${AW_PASS}" \
  --data-urlencode "destination=/")


X_BISCOTTI=$(echo "$LOGIN_HEADERS" | awk -F': ' '/^X-BISCOTTI/ {print $2}' | tr -d '\r')

if [[ -z "$X_BISCOTTI" ]]; then
  echo "[AirWave][ERROR] X-BISCOTTI token not received"
  exit 1
fi


HTTP_CODE=$(curl -k \
  -b "$COOKIE_JAR" \
  -H "X-BISCOTTI: $X_BISCOTTI" \
  -H "Content-Type: application/json" \
  -X POST \
  "https://${AW_HOST}/api/add_ssl_certificate" \
  -d "{
    \"cert_data\": \"${CERT_B64}\",
    \"passphrase\": \"${P12_PASSWORD}\"
  }" \
  -w "\n%{http_code}\n" \
  -o /tmp/airwave_cert_response.txt || true)


echo "[AirWave] HTTP status code: $HTTP_CODE"

echo "[AirWave] Raw response (may be empty due to restart):"
cat /tmp/airwave_cert_response.txt || true

echo "[AirWave] If HTTP service restarted, result is SUCCESS."

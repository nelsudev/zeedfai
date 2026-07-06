#!/usr/bin/env bash
# Obtém um access token da API da Contabo (OAuth2 password grant).
# Requer: CNTB_CLIENT_ID, CNTB_CLIENT_SECRET, CNTB_API_USER, CNTB_API_PASS
set -euo pipefail
curl -fsS -d "client_id=${CNTB_CLIENT_ID}" \
  -d "client_secret=${CNTB_CLIENT_SECRET}" \
  --data-urlencode "username=${CNTB_API_USER}" \
  --data-urlencode "password=${CNTB_API_PASS}" \
  -d 'grant_type=password' \
  'https://auth.contabo.com/auth/realms/contabo/protocol/openid-connect/token' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])'

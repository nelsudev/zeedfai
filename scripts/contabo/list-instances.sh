#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
TOKEN=$(./auth.sh)
curl -fsS 'https://api.contabo.com/v1/compute/instances' \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-request-id: $(cat /proc/sys/kernel/random/uuid)" \
  | python3 -c '
import sys, json
for i in json.load(sys.stdin).get("data", []):
    ip = (i.get("ipConfig", {}).get("v4", {}) or {}).get("ip", "?")
    print(f'"'"'{i["instanceId"]}  {i.get("displayName","")}  {i.get("status","")}  {ip}'"'"')
'

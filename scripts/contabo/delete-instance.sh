#!/usr/bin/env bash
# Cancels/destroys a Contabo instance: ./delete-instance.sh <instanceId>
set -euo pipefail
cd "$(dirname "$0")"
[ $# -eq 1 ] || { echo "usage: $0 <instanceId>"; exit 1; }
TOKEN=$(./auth.sh)
curl -fsS -X POST "https://api.contabo.com/v1/compute/instances/$1/cancel" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-request-id: $(cat /proc/sys/kernel/random/uuid)" | python3 -m json.tool

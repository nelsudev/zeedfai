#!/usr/bin/env bash
# Creates a Contabo VPS with cloud-init (k3s + flux).
set -euo pipefail
cd "$(dirname "$0")"
TOKEN=$(./auth.sh)
USER_DATA=$(python3 -c 'import json;print(json.dumps(open("cloud-init.yaml").read()))')

curl -fsS -X POST 'https://api.contabo.com/v1/compute/instances' \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "x-request-id: $(cat /proc/sys/kernel/random/uuid)" \
  -H 'Content-Type: application/json' \
  -d @- <<EOF | python3 -m json.tool
{
  "imageId": "afecbb85-e2fc-46f0-9684-b46b1faf00bb",
  "productId": "V76",
  "region": "EU",
  "period": 1,
  "displayName": "zeedfai-k3s",
  "userData": ${USER_DATA}
}
EOF
echo "Instância pedida. Vê o IP com ./list-instances.sh (imageId=Ubuntu 24.04; ajusta productId/region se necessário)."

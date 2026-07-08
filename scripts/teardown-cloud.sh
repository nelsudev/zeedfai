#!/usr/bin/env bash
# Destroys any zeedfai demo cloud resource (Contabo + Hetzner).
# Idempotent and safe by default: if a provider's credentials aren't set,
# that provider is simply skipped (never fails).
#
# Used by the .github/workflows/teardown-cloud-demo.yml GitHub Action as a
# safety net against forgotten resources burning money, and can be run
# locally the same way.
set -uo pipefail

echo "=== zeedfai: cloud demo resource teardown ==="

# --- Contabo -----------------------------------------------------------
if [[ -n "${CNTB_CLIENT_ID:-}" && -n "${CNTB_CLIENT_SECRET:-}" && -n "${CNTB_API_USER:-}" && -n "${CNTB_API_PASS:-}" ]]; then
  echo "--- Contabo: listing instances ---"
  cd "$(dirname "$0")/contabo"
  TOKEN=$(./auth.sh)
  mapfile -t IDS < <(curl -fsS 'https://api.contabo.com/v1/compute/instances' \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "x-request-id: $(cat /proc/sys/kernel/random/uuid)" \
    | python3 -c '
import sys, json
for i in json.load(sys.stdin).get("data", []):
    if str(i.get("displayName","")).startswith("zeedfai"):
        print(i["instanceId"])
')
  if [[ ${#IDS[@]} -eq 0 ]]; then
    echo "Contabo: no 'zeedfai*' instance found."
  else
    for id in "${IDS[@]}"; do
      echo "Contabo: cancelling instance $id"
      ./delete-instance.sh "$id" || echo "WARNING: failed to cancel $id"
    done
  fi
  cd - >/dev/null
else
  echo "Contabo: credentials not set (CNTB_*), skipping."
fi

# --- Hetzner Cloud -------------------------------------------------------
if [[ -n "${HCLOUD_TOKEN:-}" ]]; then
  echo "--- Hetzner: listing servers with label zeedfai=true ---"
  SERVERS=$(curl -fsS -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
    "https://api.hetzner.cloud/v1/servers?label_selector=zeedfai%3Dtrue" \
    | python3 -c 'import sys,json;[print(s["id"]) for s in json.load(sys.stdin).get("servers",[])]')
  if [[ -z "$SERVERS" ]]; then
    echo "Hetzner: no server with label zeedfai=true found."
  else
    for id in $SERVERS; do
      echo "Hetzner: deleting server $id"
      curl -fsS -X DELETE -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
        "https://api.hetzner.cloud/v1/servers/$id" || echo "WARNING: failed to delete $id"
    done
  fi
else
  echo "Hetzner: HCLOUD_TOKEN not set, skipping."
fi

echo "=== teardown complete ==="

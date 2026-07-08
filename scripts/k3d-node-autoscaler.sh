#!/usr/bin/env bash
# Local node-autoscaler for k3d: simulates on the dev machine what the
# cluster-autoscaler does on Hetzner (cloud phase) — when pods are Pending
# due to lack of resources, it creates a new node (Docker container via
# k3d); when an agent node has no workload pods left, it removes it.
#
# This is deliberately a mock with the SAME semantics as the real
# autoscaler: the demo proves the system's behavior (Pending pods → new
# capacity in ~20s → scheduling), not the provider. On Hetzner, `k3d node
# create` is swapped for real hourly-billed servers.
#
# Usage: ./k3d-node-autoscaler.sh <cluster> [max_nodes]   (Ctrl-C to stop)
set -euo pipefail
CLUSTER=${1:?usage: $0 <k3d-cluster> [max_nodes]}
MAX=${2:-4}
COOLDOWN=20

log() { echo "$(date -u +%H:%M:%S) node-autoscaler: $*"; }

pending_unschedulable() {
  kubectl get pods -A --field-selector status.phase=Pending -o json 2>/dev/null \
    | python3 -c '
import sys, json
n = 0
for p in json.load(sys.stdin).get("items", []):
    for c in p.get("status", {}).get("conditions", []):
        if c.get("type") == "PodScheduled" and c.get("reason") == "Unschedulable":
            n += 1
print(n)'
}

agent_count() { kubectl get nodes -o name | { grep -vc -- '-server-' || true; }; }

# agent nodes with no workload pods (only DaemonSets) → removal candidates
idle_agent() {
  # agents = anything that isn't a server (k3d agent nodes show up in
  # kubectl with no role and whatever name we gave them, e.g. k3d-scaled-*)
  for node in $(kubectl get nodes -o name | grep -v -- '-server-' | sed 's|node/||'); do
    n=$(kubectl get pods -A --field-selector "spec.nodeName=$node" -o json \
      | python3 -c '
import sys, json
print(sum(1 for p in json.load(sys.stdin)["items"]
          if (p.get("metadata",{}).get("ownerReferences") or [{}])[0].get("kind") != "DaemonSet"))')
    [ "$n" -eq 0 ] && { echo "$node"; return; }
  done
  true
}

log "watching cluster=$CLUSTER max_nodes=$MAX"
while true; do
  P=$(pending_unschedulable)
  A=$(agent_count)
  if [ "$P" -gt 0 ] && [ "$A" -lt "$MAX" ]; then
    log "SCALE-OUT: $P pod(s) Unschedulable, agents=$A → creating node"
    k3d node create "scaled-$(date +%s)" --cluster "$CLUSTER" --role agent --wait >/dev/null
    log "node created (agents=$((A+1))); cooldown ${COOLDOWN}s"
    sleep "$COOLDOWN"
    continue
  fi
  if [ "$P" -eq 0 ] && [ "$A" -gt 0 ]; then
    IDLE=$(idle_agent)
    if [ -n "${IDLE:-}" ]; then
      log "SCALE-IN: node $IDLE has no workload → removing"
      kubectl drain "$IDLE" --ignore-daemonsets --delete-emptydir-data --timeout=60s >/dev/null 2>&1 || true
      k3d node delete "$IDLE" >/dev/null 2>&1 || true
      # k3d removes the container but leaves the Node object orphaned in k8s
      kubectl delete node "$IDLE" --ignore-not-found >/dev/null
      log "node removed; cooldown ${COOLDOWN}s"
      sleep "$COOLDOWN"
      continue
    fi
  fi
  sleep 5
done

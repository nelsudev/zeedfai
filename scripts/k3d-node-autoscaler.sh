#!/usr/bin/env bash
# Node-autoscaler local para k3d: simula na máquina de dev o que o
# cluster-autoscaler faz na Hetzner (Fase 7) — quando há pods Pending por
# falta de recursos, cria um node novo (container Docker via k3d); quando
# um node agent fica sem pods de trabalho, remove-o.
#
# É deliberadamente um mock com a MESMA semântica do autoscaler real:
# a demo prova o comportamento do sistema (pods Pending → capacidade nova
# em ~20s → scheduling), não o provider. Na Hetzner, troca-se `k3d node
# create` por servers reais cobrados à hora.
#
# Uso: ./k3d-node-autoscaler.sh <cluster> [max_nodes]   (Ctrl-C para parar)
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

# nodes agent sem pods de workload (só DaemonSets) → candidatos a remoção
idle_agent() {
  # agents = tudo o que não é server (os nodes k3d de agent aparecem no
  # kubectl sem role e com o nome que lhes dermos, ex. k3d-scaled-*)
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
    log "SCALE-OUT: $P pod(s) Unschedulable, agents=$A → a criar node"
    k3d node create "scaled-$(date +%s)" --cluster "$CLUSTER" --role agent --wait >/dev/null
    log "node criado (agents=$((A+1))); cooldown ${COOLDOWN}s"
    sleep "$COOLDOWN"
    continue
  fi
  if [ "$P" -eq 0 ] && [ "$A" -gt 0 ]; then
    IDLE=$(idle_agent)
    if [ -n "${IDLE:-}" ]; then
      log "SCALE-IN: node $IDLE sem workload → a remover"
      kubectl drain "$IDLE" --ignore-daemonsets --delete-emptydir-data --timeout=60s >/dev/null 2>&1 || true
      k3d node delete "$IDLE" >/dev/null 2>&1 || true
      # o k3d remove o container mas deixa o objeto Node órfão no k8s
      kubectl delete node "$IDLE" --ignore-not-found >/dev/null
      log "node removido; cooldown ${COOLDOWN}s"
      sleep "$COOLDOWN"
      continue
    fi
  fi
  sleep 5
done

# Runbook: p99.9 latency SLO violated

**Alert:** `ZeedfaiSLOLatencyViolated` — p99.9 above the configured limit (default 250 ms) for >5 min.

## Impact
Scoring is outside the industry reference SLA (Feedzai's Railgun: <250ms
p99.9); risk of fraud decisions delaying the payment flow.

## Diagnosis
1. `kubectl get scoringpipeline <name> -o yaml` — check `status.conditions` and current replicas vs. `spec.scaling.maxReplicas`.
2. Grafana: latency p99.9 vs. throughput vs. consumer lag panel, same time axis.
3. Common causes:
   - Traffic burst faster than the autoscaler can react (check `targetLagPerReplica` and cooldown).
   - CPU throttling on a node/pod — `kubectl top pods`.
   - Kafka broker under pressure (only 1 broker in the local demo — no HA).

## Mitigation
- Short term: `kubectl scale deploy <name>-scorer --replicas=N` manually while investigating.
- If recurring: revise the CRD's `spec.scaling` via a PR in the GitOps repo (min/max/targetLag).

## Post-incident
Log it under `docs/postmortems/`; if the cause was insufficient capacity,
consider raising `maxReplicas` or adding nodes (see the Hetzner
node-autoscaler, cloud phase).

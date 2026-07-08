# Runbook: consumer lag growing

**Alert:** `ZeedfaiConsumerLagGrowing` — consumer group lag has been growing for >5 min.

## Impact
Scoring is falling behind; risk of breaching the p99.9 < 250 ms SLO and
making fraud decisions outside the payment flow's real-time window.

## Diagnosis
1. `kubectl get scoringpipeline <name>` — check conditions and current replicas.
2. Per-partition lag: `kubectl -n kafka exec zeedfai-dual-0 -- bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group <group>`
3. Are replicas already at the max? → the autoscaler has exhausted `maxReplicas`; consider raising it.
4. Lag stuck on a single partition only? → a stuck consumer; the operator should restart it (Phase 4); manual fallback: delete that pod.

## Mitigation
- Short term: bump `spec.scaling.maxReplicas` via a PR in the GitOps repo.
- If it's a legitimate traffic spike: confirm scale-out kept pace; otherwise open an incident.

## Post-incident
Log it under `docs/postmortems/`; review `targetLagPerReplica`.

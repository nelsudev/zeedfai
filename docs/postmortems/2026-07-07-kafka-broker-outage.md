# Post-mortem: Kafka broker outage (simulated)

**Date:** 2026-07-07 · **Duration:** ~75 s · **Severity:** SEV-2 (scoring stopped, no data loss)
**Type:** deliberately simulated incident (game day) to exercise the response.

## Impact

- Scoring stopped for ~75 s: consumers couldn't connect to the broker
  (`connection refused`), no transaction was scored in that window.
- **No data loss**: the loadgen also couldn't produce, and whatever it had
  produced before stayed in the topic — on recovery, consumers resumed from
  the committed offset. In a real scenario with external producers, lag
  would accumulate and the autoscaler would scale out on recovery.

## Timeline (UTC)

| Time | Event |
|---|---|
| 05:01:25 | `kubectl -n kafka delete pod zeedfai-dual-0` (fault injection) |
| 05:01:29 | Scorers start logging `unable to dial ... connection refused`; `zeedfai_scorer_errors_total` doesn't increment (fetch errors are logged, not counted as events) |
| 05:01:43 | StrimziPodSet recreates the broker pod (0/1 Running) |
| ~05:02:37 | Broker Ready; consumers reconnect without a restart (franz-go's internal retry) |
| 05:03:10 | Consumption confirmed flowing again (`events_total` climbing); lag drained |

## Detection

- In this exercise: direct observation. In real operation, the signals
  would be the `ZeedfaiConsumerLagGrowing` alert (if external producers kept
  producing) and the `zeedfai_operator_consumer_lag` metric flatlining or
  erroring.
- **Gap identified:** there's no alert for "operator can't measure lag"
  (broker down = the autoscaler is blind, holding its last decision). During
  the window, the operator logged `consumer lag unavailable` and kept
  replicas steady — the correct fail-safe behavior, but invisible to
  whoever's on call.

## What went well

- **Full automatic recovery, zero human intervention**: Strimzi recreated
  the broker; consumers (franz-go) reconnected on their own; the operator
  held steady during the blindness window instead of reacting to noise.
- The `ScoringPipeline` stayed `Available=True` throughout the incident —
  correct, because the replicas themselves were healthy; the problem was
  the dependency, not the workload.

## What was missing / action items

| Action | Priority |
|---|---|
| `ZeedfaiLagMeasurementFailing` alert: operator unable to measure lag for >2 min (new metric or Event) | P1 |
| Multi-broker Kafka (the demo uses 1 ephemeral broker — in production, ≥3 with `min.insync.replicas=2`) | P1 (documented as a demo limitation) |
| Dedicated `DependenciesHealthy` condition on `ScoringPipeline`, to distinguish "workload healthy" from "pipeline functional end-to-end" | P2 |
| Runbook for broker outages (this document is the starting point) | P2 |

## Lessons

1. Silent fail-safe is only half the job: the system behaved well, but an
   on-call human had no way to know the autoscaler was blind.
   Observability of the control loop itself matters as much as
   observability of the workload.
2. `Available=True` during a dependency outage is technically correct and
   operationally misleading — conditions should separate the two concepts.

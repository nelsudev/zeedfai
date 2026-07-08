# ADR-0001: Latency SLO and reference architecture

## Context

Fraud-scoring systems are mission-critical: the decision has to happen
within the payment flow. The industry reference (see Feedzai's Railgun
paper, arXiv:2009.00361) is **scoring in < 250 ms at p99.9**.

## Decision

- Default SLO for `ScoringPipeline`: `latencyP999Ms: 250`.
- Autoscaling driven by **consumer lag** (a business metric), not CPU: lag
  is the leading indicator of a latency violation in a Kafka consumer.
- Scale-down with cooldown/hysteresis to avoid flapping under bursty traffic.
- Kubernetes Operator (rather than Helm+HPA) because the lifecycle includes
  domain logic: SLO-driven decisions, restarting stuck consumers, canary by
  consumer group.

## Consequences

- The controller needs access to Kafka (AdminClient for lag) and to
  Prometheus (latency) — autoscaler phase.
- kind is enough for dev; validating p99.9 under real load requires a
  cluster with dedicated nodes (cloud phase: GKE/EKS via Terraform, or k3s
  on Contabo).

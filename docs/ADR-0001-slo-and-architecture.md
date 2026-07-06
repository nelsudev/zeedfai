# ADR-0001: SLO de latência e arquitetura de referência

## Contexto

Sistemas de fraud-scoring são mission-critical: a decisão tem de acontecer
dentro do fluxo do pagamento. A referência da indústria (ver o paper do
Railgun da Feedzai, arXiv:2009.00361) é **scoring em < 250 ms no p99.9**.

## Decisão

- SLO default do `ScoringPipeline`: `latencyP999Ms: 250`.
- Autoscaling orientado a **consumer lag** (métrica de negócio), não CPU:
  lag é o indicador antecipado de violação de latência num consumidor Kafka.
- Scale-down com cooldown/histerese para evitar flapping em tráfego bursty.
- Kubernetes Operator (e não Helm+HPA) porque o ciclo de vida inclui lógica
  de domínio: decisões por SLO, restart de consumers presos, canary por
  consumer group.

## Consequências

- O controller precisa de acesso ao Kafka (AdminClient para lag) e ao
  Prometheus (latência) — fase 4.
- kind chega para dev; a validação de p99.9 sob carga real requer um cluster
  com nodes dedicados (fase 7: GKE/EKS via Terraform, ou k3s na Contabo).

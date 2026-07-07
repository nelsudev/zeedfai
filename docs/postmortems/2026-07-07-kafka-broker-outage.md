# Post-mortem: outage do broker Kafka (simulado)

**Data:** 2026-07-07 · **Duração:** ~75 s · **Severidade:** SEV-2 (scoring parado, sem perda de dados)
**Tipo:** incidente simulado deliberadamente (game day) para exercitar a resposta.

## Impacto

- Scoring parado durante ~75 s: os consumidores não conseguiam ligar ao
  broker (`connection refused`), nenhuma transação foi pontuada na janela.
- **Sem perda de dados**: o loadgen também não conseguia produzir, e o que
  produziu antes ficou no tópico — ao recuperar, os consumidores retomaram
  do offset committed. Num cenário real com produtores externos, o lag
  acumularia e o autoscaler faria scale-out na recuperação.

## Timeline (UTC)

| Hora | Evento |
|---|---|
| 05:01:25 | `kubectl -n kafka delete pod zeedfai-dual-0` (injeção da falha) |
| 05:01:29 | Scorers começam a registar `unable to dial ... connection refused`; `zeedfai_scorer_errors_total` não incrementa (erros de fetch são logados, não contados como eventos) |
| 05:01:43 | StrimziPodSet recria o pod do broker (0/1 Running) |
| ~05:02:37 | Broker Ready; consumidores religam-se sem restart (retry interno do franz-go) |
| 05:03:10 | Consumo confirmado a fluir (`events_total` a crescer); lag drenado |

## Deteção

- Neste exercício: observação direta. Em operação real, os sinais seriam
  o alerta `ZeedfaiConsumerLagGrowing` (se produtores externos continuassem
  a produzir) e a métrica `zeedfai_operator_consumer_lag` em flatline/erro.
- **Gap identificado:** não existe alerta para "operator não consegue medir
  o lag" (broker em baixo = autoscaler cego, a manter a última decisão).
  Durante a janela, o operator logou `consumer lag unavailable` e manteve
  as réplicas — comportamento fail-safe correto, mas invisível para quem
  está de serviço.

## O que correu bem

- **Auto-recuperação total sem intervenção humana**: Strimzi recriou o
  broker; os consumidores (franz-go) religaram-se sozinhos; o operator
  manteve o estado estável durante a cegueira em vez de reagir a ruído.
- O `ScoringPipeline` manteve `Available=True` durante todo o incidente —
  correto, porque as réplicas estavam saudáveis; o problema era a
  dependência, não o workload.

## O que faltou / ações

| Ação | Prioridade |
|---|---|
| Alerta `ZeedfaiLagMeasurementFailing`: operator sem conseguir medir lag por >2 min (nova métrica ou Event) | P1 |
| Kafka multi-broker (a demo usa 1 broker ephemeral — em produção, ≥3 com `min.insync.replicas=2`) | P1 (documentado como limitação da demo) |
| Condition dedicada `DependenciesHealthy` no ScoringPipeline, para distinguir "workload saudável" de "pipeline funcional ponta-a-ponta" | P2 |
| Runbook para outage de broker (este documento serve de base) | P2 |

## Lições

1. Fail-safe silencioso é meio caminho: o sistema comportou-se bem, mas um
   humano de serviço não teria como saber que o autoscaler estava cego.
   Observabilidade da própria malha de controlo é tão importante como a do
   workload.
2. `Available=True` durante um outage de dependência é tecnicamente correto
   e operacionalmente enganador — as conditions devem separar os dois
   conceitos.

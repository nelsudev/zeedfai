# Runbook: consumer lag a crescer

**Alerta:** `ZeedfaiConsumerLagGrowing` — lag do consumer group cresce há >5 min.

## Impacto
Scoring atrasado; risco de violar o SLO p99.9 < 250 ms e de decisões fora do
fluxo do pagamento.

## Diagnóstico
1. `kubectl get scoringpipeline <nome>` — ver conditions e réplicas.
2. Lag por partição: `kubectl -n kafka exec zeedfai-dual-0 -- bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group <grupo>`
3. Réplicas no máximo? → o autoscaler esgotou `maxReplicas`; avaliar aumentar.
4. Lag estagnado numa partição só? → consumer preso; o operator deve reiniciá-lo (F4); manual: apagar o pod.

## Mitigação
- Curto prazo: subir `spec.scaling.maxReplicas` via PR no repo GitOps.
- Se for pico legítimo de tráfego: confirmar que o scale-out acompanhou; senão, abrir incidente.

## Pós-incidente
Registar em `docs/postmortems/`, rever `targetLagPerReplica`.

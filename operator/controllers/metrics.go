package controllers

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	crmetrics "sigs.k8s.io/controller-runtime/pkg/metrics"
)

// Métricas exportadas pelo próprio operator (não pelo scorer), para que o
// platform-api/GUI (Fase 6) tenha uma série temporal de lag/réplicas mesmo
// quando não há eventos suficientes vindos do scorer.
//
// Registadas no registry do controller-runtime (crmetrics.Registry), que é
// o que o metrics server do manager serve em :8083 — o DefaultRegisterer
// do client_golang NÃO é servido pelo controller-runtime.
var (
	factory = promauto.With(crmetrics.Registry)

	consumerLagGauge = factory.NewGaugeVec(prometheus.GaugeOpts{
		Name: "zeedfai_operator_consumer_lag",
		Help: "Consumer lag observado pelo operator na última avaliação de autoscaling.",
	}, []string{"pipeline"})

	desiredReplicasGauge = factory.NewGaugeVec(prometheus.GaugeOpts{
		Name: "zeedfai_operator_desired_replicas",
		Help: "Réplicas decididas pelo autoscaler para o pipeline.",
	}, []string{"pipeline"})

	readyReplicasGauge = factory.NewGaugeVec(prometheus.GaugeOpts{
		Name: "zeedfai_operator_ready_replicas",
		Help: "Réplicas prontas do Deployment do scorer.",
	}, []string{"pipeline"})
)

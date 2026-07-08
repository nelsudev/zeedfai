package controllers

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	crmetrics "sigs.k8s.io/controller-runtime/pkg/metrics"
)

// Metrics exported by the operator itself (not by the scorer), so the
// platform-api/GUI has a time series for lag/replicas even when there
// aren't enough events coming from the scorer.
//
// Registered in the controller-runtime registry (crmetrics.Registry),
// which is what the manager's metrics server serves on :8083 — the
// client_golang DefaultRegisterer is NOT served by controller-runtime.
var (
	factory = promauto.With(crmetrics.Registry)

	consumerLagGauge = factory.NewGaugeVec(prometheus.GaugeOpts{
		Name: "zeedfai_operator_consumer_lag",
		Help: "Consumer lag observed by the operator at the last autoscaling evaluation.",
	}, []string{"pipeline"})

	desiredReplicasGauge = factory.NewGaugeVec(prometheus.GaugeOpts{
		Name: "zeedfai_operator_desired_replicas",
		Help: "Replicas decided by the autoscaler for the pipeline.",
	}, []string{"pipeline"})

	readyReplicasGauge = factory.NewGaugeVec(prometheus.GaugeOpts{
		Name: "zeedfai_operator_ready_replicas",
		Help: "Ready replicas of the scorer Deployment.",
	}, []string{"pipeline"})
)

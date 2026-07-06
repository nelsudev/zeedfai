package controllers

import "k8s.io/apimachinery/pkg/util/intstr"

func intstrFromInt(i int) intstr.IntOrString { return intstr.FromInt(i) }

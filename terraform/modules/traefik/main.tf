resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  namespace  = "traefik"
  version    = "26.0.0"

  create_namespace = true

  set = [
   {
    name  = "deployment.replicas"
    value = "2"
  },
  # Enable access logs
  {
    name  = "logs.access.enabled"
    value = "true"
  },
  # Enable dashboard via IngressRoute
  {
    name  = "ingressRoute.dashboard.enabled"
    value = "true"
  },
  # Enable service as LoadBalancer
  {
    name  = "service.type"
    value = "LoadBalancer"
  },
  {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"          # ✅ makes it public
  },
  # Enable metrics (Prometheus)
   {
    name  = "metrics.prometheus.enabled"
    value = "true"
  }
  ]
}

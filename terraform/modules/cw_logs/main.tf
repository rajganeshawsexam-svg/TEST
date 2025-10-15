resource "helm_release" "fluent_bit" {
  name             = "fluent-bit"
  repository       = "https://fluent.github.io/helm-charts"
  chart            = "fluent-bit"
  namespace        = "logging"
  version          = "0.47.9"
  create_namespace = true

  set = [{
    name  = "backend.type"
    value = "cloudwatch"
  },

  {
    name  = "backend.cloudwatch.region"
    value = var.region
  },

 {
    name  = "backend.cloudwatch.logGroupName"
    value = "/eks/${var.cluster_name}/app-logs"
  },

  {
    name  = "backend.cloudwatch.logStreamPrefix"
    value = "fluentbit-"
  },

   {
    name  = "serviceAccount.create"
    value = "true"
  },

   {
    name  = "serviceAccount.name"
    value = "fluent-bit"
  }
  ]
}

#https://agones.dev/site/docs/guides/metrics/#prometheus-installation
locals {
  helm_values_prometheus = [
    ["server.global.scrape_interval", "30s"],
    ["server.persistentVolume.enabled", "false"],
    ["server.persistentVolume.size", "16Gi"],
  ]
}

data "github_repository_file" "prometheus_config_file" {
  repository = "googleforgames/agones"
  branch     = local.agones_github_branch
  file       = "build/prometheus.yaml"
}

resource "helm_release" "prometheus" {
  repository       = "https://prometheus-community.github.io/helm-charts"
  name             = "prom"
  chart            = "prometheus"
  namespace        = "metrics"
  version          = "25.1.0"
  create_namespace = true

  dynamic "set" {
    for_each = local.helm_values_prometheus
    content {
      name  = set.value[0]
      value = set.value[1]
    }
  }

  values = [
    "${data.github_repository_file.prometheus_config_file.content}"
  ]

  depends_on = [
    minikube_cluster.lyra_on_minikube_agones,
    helm_release.agones,
  ]
}

#https://agones.dev/site/docs/guides/metrics/#grafana-installation
locals {
  helm_values_grafana = [
    ["adminPassword", "${random_password.grafana_password.result}"],
  ]
}

resource "random_password" "grafana_password" {
  length           = 10
  special          = true
  override_special = "!#$%&*()-_=+[]<>:?"
}

locals {
  github_tag                   = "v1.33.0"
  release_dir_name             = "agones_${replace(local.github_tag, ".", "_")}"
  agones_grafana_dashboard_dir = "${local.release_dir_name}/agones/build/grafana"
}

module "fetch_grafana_config" {
  source             = "../modules/fetch_grafana_config"
  release_dir_name   = local.release_dir_name
  github_release_tag = local.github_tag
}

#https://github.com/googleforgames/agones/blob/614c9adbaff21fb72e06bb17fb481a3a6cbbf3fa/build/grafana/dashboard-allocations.yaml
#apply under https://github.com/googleforgames/agones/tree/main/build/grafana
resource "terraform_data" "apply_granfana_configs" {
  triggers_replace = [
    minikube_cluster.lyra_on_minikube_agones.id
  ]

  provisioner "local-exec" {
    command = "kubectl apply -f ${local.agones_grafana_dashboard_dir}"
  }

  depends_on = [
    helm_release.prometheus,
    terraform_data.switch_profile,
    module.fetch_grafana_config,
  ]
}

resource "helm_release" "grafana" {
  repository       = "https://grafana.github.io/helm-charts"
  name             = "grafana"
  chart            = "grafana"
  namespace        = "metrics"
  version          = "6.60.4"
  create_namespace = true
  timeout          = 600

  dynamic "set" {
    for_each = local.helm_values_grafana
    content {
      name  = set.value[0]
      value = set.value[1]
    }
  }

  values = [
    module.fetch_grafana_config.yaml_manifest
  ]

  depends_on = [
    helm_release.prometheus,
    terraform_data.apply_granfana_configs,
    module.fetch_grafana_config,
  ]
}

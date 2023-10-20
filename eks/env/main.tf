locals {
  helm_values_agones = []
}

resource "kubernetes_namespace" "agones_gameserver" {
  metadata {
    name = "agones-gameserver"
  }

  depends_on = [
    module.eks
  ]

  timeouts {
    delete = "10m"
  }
}

data "helm_template" "agones" {
  repository        = "https://agones.dev/chart/stable"
  name              = local.cluster_name
  chart             = "agones"
  namespace         = "agones-system"
  version           = "1.33.0"
  dependency_update = true

  dynamic "set" {
    for_each = local.helm_values_agones
    content {
      name  = set.value[0]
      value = set.value[1]
    }
  }

  values = [
    file("values_agones.yaml")
  ]

  depends_on = [
    module.vpc,
    module.eks,
  ]
}

resource "helm_release" "agones" {
  name              = data.helm_template.agones.name
  repository        = data.helm_template.agones.repository
  chart             = data.helm_template.agones.chart
  namespace         = data.helm_template.agones.namespace
  version           = data.helm_template.agones.version
  create_namespace  = true
  dependency_update = true
  timeout           = 600

  dynamic "set" {
    for_each = local.helm_values_agones
    content {
      name  = set.value[0]
      value = set.value[1]
    }
  }

  values = [
    file("values_agones.yaml")
  ]

  depends_on = [
    module.vpc,
    module.eks,
    kubernetes_namespace.agones_gameserver
  ]
}

locals {
  ecr_repository_name = "lyra-on-k8s-agones"
  ecr_repository      = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/${local.ecr_repository_name}"
  ecr_tag             = "debug"
  helm_values_lyra_gameserver = [
    ["containers.repository", "${local.ecr_repository}"],
    ["containers.imageTag", "${local.ecr_tag}"],
  ]
}

data "helm_template" "lyra_gameserver" {
  name              = "lyra-gameserver"
  chart             = "./gameserver"
  namespace         = "agones-gameserver"
  dependency_update = true
  create_namespace  = true

  dynamic "set" {
    for_each = local.helm_values_lyra_gameserver
    content {
      name  = set.value[0]
      value = set.value[1]
    }
  }

  values = [
    file("values.yaml")
  ]

  depends_on = [
    helm_release.agones,
    helm_release.grafana,
    kubernetes_namespace.agones_gameserver
  ]
}

resource "helm_release" "lyra_gameserver" {
  name              = data.helm_template.lyra_gameserver.name
  repository        = data.helm_template.lyra_gameserver.repository
  chart             = data.helm_template.lyra_gameserver.chart
  namespace         = data.helm_template.lyra_gameserver.namespace
  version           = data.helm_template.lyra_gameserver.version
  create_namespace  = true
  dependency_update = true
  force_update      = true
  wait              = true

  dynamic "set" {
    for_each = local.helm_values_lyra_gameserver
    content {
      name  = set.value[0]
      value = set.value[1]
    }
  }

  values = data.helm_template.agones.values

  depends_on = [
    module.vpc,
    module.eks,
    helm_release.agones,
    helm_release.grafana,
  ]
}


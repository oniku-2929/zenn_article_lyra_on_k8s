
locals {
  is_unix            = substr(abspath(path.cwd), 0, 1) == "/"
  driver             = "docker"
  kubernetes_version = "v1.27.3"
  cluster_name       = "lyra-on-minikube-agones"
}

provider "minikube" {
  kubernetes_version = local.kubernetes_version
}

resource "minikube_cluster" "lyra_on_minikube_agones" {
  cluster_name       = local.cluster_name
  kubernetes_version = local.kubernetes_version
  driver             = local.driver
  memory             = "8192mb"
  cpus               = 8
  disk_size          = "30000m"
  vm                 = true
  preload            = true

  network_plugin    = "cni"
  cni               = "bridge"
  container_runtime = "containerd"
  network           = ""

  mount = false
  addons = [
    "default-storageclass",
    "storage-provisioner",
    "metrics-server",
  ]

  ports = [
    "32774:8443",
    "7000-8000:7000-8000/udp",
  ]
}

resource "terraform_data" "switch_profile" {
  triggers_replace = [
    minikube_cluster.lyra_on_minikube_agones.id,
  ]

  provisioner "local-exec" {
    command = "minikube profile ${local.cluster_name}"
  }
}

locals {
  helm_values_agones = [
    ["agones.allocator.service.serviceType", "ClusterIP"],
    ["agones.ping.http.serviceType", "ClusterIP"],
    ["agones.ping.udp.serviceType", "ClusterIP"],
    ["gameservers.namespaces[0]", "default"],
    ["gameservers.namespaces[1]", "agones-gameserver"],
  ]
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = local.cluster_name
    host           = minikube_cluster.lyra_on_minikube_agones.host
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
  host        = minikube_cluster.lyra_on_minikube_agones.host
}

resource "kubernetes_namespace" "agones_gameserver" {
  metadata {
    name = "agones-gameserver"
  }

  depends_on = [
    terraform_data.switch_profile,
    minikube_cluster.lyra_on_minikube_agones,
  ]
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

  depends_on = [
    terraform_data.switch_profile,
    minikube_cluster.lyra_on_minikube_agones
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
  wait              = true

  dynamic "set" {
    for_each = local.helm_values_agones
    content {
      name  = set.value[0]
      value = set.value[1]
    }
  }

  depends_on = [
    minikube_cluster.lyra_on_minikube_agones,
    kubernetes_namespace.agones_gameserver
  ]
}

provider "docker" {
  #https://github.com/hashicorp/terraform-provider-docker/issues/180
  host = local.is_unix ? "unix:///var/run/docker.sock" : "npipe:////.//pipe//docker_engine"
}

data "docker_image" "lyra_server_debug" {
  name = "lyra-on-k8s-agones:debug"
}

resource "terraform_data" "load_image" {
  triggers_replace = [
    data.docker_image.lyra_server_debug.id,
  ]

  provisioner "local-exec" {
    command = "minikube image load ${data.docker_image.lyra_server_debug.name} --profile ${local.cluster_name}"
  }

  depends_on = [
    minikube_cluster.lyra_on_minikube_agones,
    terraform_data.switch_profile,
  ]
}

data "helm_template" "lyra_gameserver" {
  name              = "lyra-gameserver"
  chart             = "./gameserver"
  namespace         = "agones-gameserver"
  dependency_update = true
  create_namespace  = true

  values = [
    file("values.yaml")
  ]

  depends_on = [
    helm_release.agones,
    terraform_data.load_image
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

  values = data.helm_template.agones.values

  depends_on = [
    kubernetes_namespace.agones_gameserver,
    minikube_cluster.lyra_on_minikube_agones,
    terraform_data.load_image,
    helm_release.agones
  ]
}

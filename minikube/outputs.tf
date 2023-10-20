
output "agones_manifests" {
  value       = var.enable_manifest_output ? data.helm_template.agones.manifests : null
  description = "The yaml manifests genareted by Helm for Agones."
}

output "gameserver_manifests" {
  value       = var.enable_manifest_output ? data.helm_template.lyra_gameserver.manifests : null
  description = "The yaml manifests genareted by Helm for Game Server."
}

output "grafana_password" {
  value = nonsensitive(random_password.grafana_password.result)
}

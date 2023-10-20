output "grafana_password" {
  value = nonsensitive(random_password.grafana_password.result)
}

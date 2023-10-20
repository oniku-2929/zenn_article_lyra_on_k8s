output "root_dir" {
  value = local.release_dir_name
}

output "downloaded_release_dir" {
  value = "${local.release_dir_name}/agones/"
}

output "yaml_manifest" {
  value = data.local_file.grafana_yaml_file.content
}

locals {
  release_dir_name = var.release_dir_name
  agones_url       = "https://github.com/googleforgames/agones.git"
}

resource "terraform_data" "fetch_grafana_config" {
  triggers_replace = [
    local.release_dir_name,
  ]

  provisioner "local-exec" {
    command = "rm -rf ${local.release_dir_name} && mkdir ${local.release_dir_name}"
  }

  provisioner "local-exec" {
    command = "cd ${local.release_dir_name} && git clone -b ${var.github_release_tag} --filter=blob:none --sparse ${local.agones_url}"
  }

  provisioner "local-exec" {
    command = "cd ${local.release_dir_name}/agones && git sparse-checkout set build/grafana"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${self.triggers_replace[0]}"
  }
}

data "local_file" "grafana_yaml_file" {
  filename = "${path.cwd}/${local.release_dir_name}/agones/build/grafana.yaml"
  depends_on = [
    terraform_data.fetch_grafana_config
  ]
}

resource "null_resource" "remove_scale_host_entry_play" {
  count = (tobool(var.turn_on) == true && (var.create_scale_cluster) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 50 -i ${local.scale_all_inventory} ${local.remove_hostentry_playbooks_path}"
  }
  triggers = {
    build = timestamp()
  }
}

resource "null_resource" "remove_deployer_host_entry_play" {
  count = (tobool(var.turn_on) == true && (var.create_scale_cluster) == true) ? 1 : 0
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "sudo ansible-playbook -f 50 -i localhost, ${local.remove_hostentry_playbooks_path}"
  }
  triggers = {
    build = timestamp()
  }
  depends_on = [null_resource.remove_scale_host_entry_play]
}

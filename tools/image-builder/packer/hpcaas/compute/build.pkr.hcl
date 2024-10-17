build {
  sources = ["source.ibmcloud-vpc.itself"]

  provisioner "shell" {
    execute_command = "export INSTALL_SYSDIG=${var.install_sysdig} && bash '{{.Path}}'"
    script = "/var/packer/hpcaas/compute/script.sh"
  }

  provisioner "shell" {
    script = "/var/packer/hpcaas/compute/customer_script.sh"
  }
}

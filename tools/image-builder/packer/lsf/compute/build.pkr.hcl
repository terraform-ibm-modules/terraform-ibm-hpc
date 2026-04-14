build {
  sources = ["source.ibmcloud-vpc.itself"]

  provisioner "shell" {
    execute_command = "export INSTALL_SYSDIG=${var.install_sysdig} && sudo -E bash '{{.Path}}'"
    script = "/var/packer/lsf/compute/script.sh"
  }

  provisioner "shell" {
    script = "/var/packer/lsf/compute/customer_script.sh"
  }
  provisioner "file" {
    direction   = "download"
    source      = "/var/log/hpc_summary.log"
    destination = "/var/log/hpc_summary.log"
  }
}

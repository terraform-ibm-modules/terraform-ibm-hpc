###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################

/*
    This module used to run null for LSF utilities
*/

resource "null_resource" "remote_exec_script_cp_files" {
  count = length(var.cluster_host) * length(var.payload_files)

  provisioner "file" {
    connection {
      type                = "ssh"
      host                = var.cluster_host[floor(count.index / length(var.payload_files))]
      user                = var.cluster_user
      private_key         = var.cluster_private_key
      bastion_host        = var.login_host
      bastion_user        = var.login_user
      bastion_private_key = var.login_private_key
    }
    source      = var.payload_files[count.index % length(var.payload_files)]
    destination = "/tmp/${basename(var.payload_files[count.index % length(var.payload_files)])}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "true"
  }

  triggers = {
    trigger_string = var.trigger_string
  }
}

resource "null_resource" "remote_exec_script_cp_dirs" {
  count = length(var.cluster_host) * length(var.payload_dirs)

  provisioner "file" {
    connection {
      type                = "ssh"
      host                = var.cluster_host[floor(count.index / length(var.payload_dirs))]
      user                = var.cluster_user
      private_key         = var.cluster_private_key
      bastion_host        = var.login_host
      bastion_user        = var.login_user
      bastion_private_key = var.login_private_key
    }
    source      = var.payload_dirs[count.index % length(var.payload_dirs)]
    destination = "/tmp/"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "true"
  }

  triggers = {
    trigger_string = var.trigger_string
  }
}

resource "null_resource" "remote_exec_script_new_file" {
  count = var.new_file_name != "" ? length(var.cluster_host) : 0

  provisioner "file" {
    connection {
      type                = "ssh"
      host                = var.cluster_host[count.index]
      user                = var.cluster_user
      private_key         = var.cluster_private_key
      bastion_host        = var.login_host
      bastion_user        = var.login_user
      bastion_private_key = var.login_private_key
    }
    content     = var.new_file_content
    destination = "/tmp/${var.new_file_name}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "true"
  }

  depends_on = [
    null_resource.remote_exec_script_cp_dirs # we may want to create the file in a subpath created with the cp_dirs
  ]
  triggers = {
    trigger_string = var.trigger_string
  }
}

resource "null_resource" "remote_exec_script_run" {
  count = length(var.cluster_host)

  provisioner "remote-exec" {
    connection {
      type                = "ssh"
      host                = var.cluster_host[count.index]
      user                = var.cluster_user
      private_key         = var.cluster_private_key
      bastion_host        = var.login_host
      bastion_user        = var.login_user
      bastion_private_key = var.login_private_key
    }
    inline = [
      "sh -c \"chmod +x /tmp/${var.script_to_run}\"",
      "cd /tmp && ${local.final_command}"
    ]
  }

  provisioner "local-exec" {
    when    = destroy
    command = "true"
  }

  depends_on = [
    null_resource.remote_exec_script_cp_files,
    null_resource.remote_exec_script_cp_dirs,
    null_resource.remote_exec_script_new_file
  ]
  triggers = {
    trigger_string = var.trigger_string
  }
}

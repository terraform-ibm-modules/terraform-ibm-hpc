###################################################
# Copyright (C) IBM Corp. 2023 All Rights Reserved.
# Licensed under the Apache License v2.0
###################################################
# This file contains the complete information on all the validations performed from the code during the generate plan process
# Validations are performed to make sure, the appropriate error messages are displayed to user in-order to provide required input parameter

locals {

  # Validation: When using a custom image in management_instances, all instances must use custom images only. Mixing custom and stock images is not supported.
  mgmt_custom_image_only_cnd = alltrue([
    for inst in var.management_instances :
    !contains([for i in var.management_instances : can(regex("^hpc-", i.image))], true) || can(regex("^hpc-", inst.image))
  ])
  mgmt_custom_image_only_msg = "When using a custom image in management_instances, all instances must use custom images only. Mixing custom and stock images is not supported."
  # tflint-ignore: terraform_unused_declarations
  mgmt_custom_image_only_chk = regex("^${local.mgmt_custom_image_only_msg}$", (local.mgmt_custom_image_only_cnd ? local.mgmt_custom_image_only_msg : ""))


  # Validation: When using a custom image in static_compute_instances, all instances must use custom images only. Mixing custom and stock images is not supported.
  cmpt_custom_image_only_cnd = alltrue([
    for inst in var.static_compute_instances :
    !contains([for i in var.static_compute_instances : can(regex("^hpc-", i.image))], true) || can(regex("^hpc-", inst.image))
  ])
  cmpt_custom_image_only_msg = "When using a custom image in static_compute_instances, all instances must use custom images only. Mixing custom and stock images is not supported."
  # tflint-ignore: terraform_unused_declarations
  cmpt_custom_image_only_chk = regex("^${local.cmpt_custom_image_only_msg}$", (local.cmpt_custom_image_only_cnd ? local.cmpt_custom_image_only_msg : ""))


  # # Validation 2: All stock images must use same OS family
  # mgmt_stock_os_consistency_cnd = (
  # length(distinct([
  #     for inst in var.management_instances :
  #     can(regex("^ibm-[^-]+-([^-]+)", inst.image)) ? regex("^ibm-[^-]+-([^-]+)", inst.image)[0] : ""
  # ])) <= 1
  # )
  # mgmt_stock_os_consistency_msg = "When using IBM stock images (starting with 'ibm-'), all instances must use the same OS family (e.g., all redhat, debian, etc.)."
  # # tflint-ignore: terraform_unused_declarations
  # mgmt_stock_os_consistency_chk = regex("^${local.mgmt_stock_os_consistency_msg}$", (local.mgmt_stock_os_consistency_cnd ? local.mgmt_stock_os_consistency_msg : ""))


  # Validation: If using IBM stock image in management_instances, it must be Red Hat
  mgmt_stock_image_redhat_only_cnd = alltrue([
    for inst in var.management_instances :
    (
      # Allow if not stock (doesn't start with ibm-)
      !can(regex("^ibm-", inst.image)) ||
      # If it starts with ibm-, ensure it contains 'ibm-redhat'
      can(regex("^ibm-redhat-", inst.image))
    )
  ])
  mgmt_stock_image_redhat_only_msg = "When using a stock image in `management_instances`, only Red Hat images are supported."
  # tflint-ignore: terraform_unused_declarations
  mgmt_stock_image_redhat_only_chk = regex(
    "^${local.mgmt_stock_image_redhat_only_msg}$",
    local.mgmt_stock_image_redhat_only_cnd ? local.mgmt_stock_image_redhat_only_msg : ""
  )


  # Validation: IBM Cloud Monitoring validation
  validate_observability_monitoring_enable_compute_nodes = (var.observability_monitoring_enable && var.observability_monitoring_on_compute_nodes_enable) || (var.observability_monitoring_enable && var.observability_monitoring_on_compute_nodes_enable == false) || (var.observability_monitoring_enable == false && var.observability_monitoring_on_compute_nodes_enable == false)
  observability_monitoring_enable_compute_nodes_msg      = "To enable monitoring on compute nodes, IBM Cloud Monitoring must also be enabled."
  # tflint-ignore: terraform_unused_declarations
  observability_monitoring_enable_compute_nodes_chk = regex(
    "^${local.observability_monitoring_enable_compute_nodes_msg}$",
  (local.validate_observability_monitoring_enable_compute_nodes ? local.observability_monitoring_enable_compute_nodes_msg : ""))


  # Validation: Existing Storage security group validation
  validate_existing_storage_sg     = length([for share in var.custom_file_shares : { mount_path = share.mount_path, nfs_share = share.nfs_share } if share.nfs_share != null && share.nfs_share != ""]) > 0 ? var.storage_security_group_id != null ? true : false : true
  validate_existing_storage_sg_msg = "Storage security group ID cannot be null when NFS share mount path is provided under cluster_file_shares variable."
  # tflint-ignore: terraform_unused_declarations
  validate_existing_storage_sg_chk = regex(
    "^${local.validate_existing_storage_sg_msg}$",
  (local.validate_existing_storage_sg ? local.validate_existing_storage_sg_msg : ""))

}

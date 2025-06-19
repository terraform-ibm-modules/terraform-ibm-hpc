resource "ibm_is_share" "share" {
  count               = var.file_shares != null ? length(var.file_shares) : 0
  name                = format("%s-fs", var.file_shares[count.index]["name"])
  resource_group      = var.resource_group_id
  access_control_mode = var.security_group_ids != null ? "security_group" : "vpc"
  size                = var.file_shares[count.index]["size"]
  profile             = "dp2"
  iops                = var.file_shares[count.index]["iops"]
  zone                = var.zone
  encryption_key      = var.encryption_key_crn
}

resource "ibm_iam_authorization_policy" "policy" {
  count                       = var.kms_encryption_enabled == false || var.skip_iam_share_authorization_policy ? 0 : 1
  source_service_name         = "is"
  source_resource_type        = "share"
  target_service_name         = "kms"
  target_resource_instance_id = var.existing_kms_instance_guid
  roles                       = ["Reader"]
}

resource "time_sleep" "wait_for_authorization_policy" {
  depends_on      = [ibm_iam_authorization_policy.policy[0]]
  create_duration = "30s"
}

resource "ibm_is_share_mount_target" "share_target_vpc" {
  count = var.file_shares != null && var.security_group_ids == null ? length(var.file_shares) : 0
  share = ibm_is_share.share[count.index].id
  name  = format("%s-fs-mount-target", var.file_shares[count.index]["name"])
  vpc   = var.vpc_id
}

resource "ibm_is_share_mount_target" "share_target_sg" {
  count = var.file_shares != null && var.security_group_ids != null ? length(var.file_shares) : 0
  share = ibm_is_share.share[count.index].id
  name  = format("%s-fs-mount-target", var.file_shares[count.index]["name"])
  virtual_network_interface {
    primary_ip {
      name = format("%s-fs-pip", var.file_shares[count.index]["name"])
    }
    subnet          = var.subnet_id
    name            = format("%s-fs-vni", var.file_shares[count.index]["name"])
    security_groups = var.security_group_ids
  }
  # TODO: update transit_encryption value conditionaly; it fails with
  # transit_encryption = "user_managed"
}

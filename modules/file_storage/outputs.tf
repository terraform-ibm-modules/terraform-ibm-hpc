output "mount_path" {
  description = "Mount path"
  value = flatten([
    ibm_is_share_mount_target.share_target_vpc[*].mount_path,
    ibm_is_share_mount_target.share_target_sg[*].mount_path
  ])
}

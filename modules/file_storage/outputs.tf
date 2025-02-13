output "mount_path" {
  description = "Mount path"
  value = flatten([
    ibm_is_share_mount_target.share_target_vpc[*].mount_path,
    ibm_is_share_mount_target.share_target_sg[*].mount_path
  ])
}

output "name_mount_path_map" {
  description = "Mount path name and its path map"
  value = { for mount_details in flatten([ibm_is_share_mount_target.share_target_vpc, ibm_is_share_mount_target.share_target_sg]) : split("-", mount_details.name)[length(split("-", mount_details.name)) - 4] => mount_details.mount_path }
}
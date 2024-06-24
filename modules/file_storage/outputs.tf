output "mount_path" {
  description = "Mount path"
  value = flatten([
    ibm_is_share_mount_target.share_target_vpc[*].mount_path,
    ibm_is_share_mount_target.share_target_sg[*].mount_path
  ])
}

output "mount_paths_info" {
  description = "Information about mount paths"
  value = {
    original_list_length  = length(ibm_is_share_mount_target.share_target_sg[*].mount_path)
    original_list         = ibm_is_share_mount_target.share_target_sg[*].mount_path
    exclude_first_element = length(ibm_is_share_mount_target.share_target_sg[*].mount_path) > 1 ? slice(ibm_is_share_mount_target.share_target_sg[*].mount_path, 1, length(ibm_is_share_mount_target.share_target_sg[*].mount_path) - 1) : []
  }
}

output "mount_path_1" {
  description = "Mount path"
  #value = ibm_is_share_mount_target.share_target_sg[0].mount_path
  #value = output "mount_path_1" {
  value = length(ibm_is_share_mount_target.share_target_sg) > 0 ? ibm_is_share_mount_target.share_target_sg[0].mount_path : null
}

output "mount_paths_excluding_first" {
  description = "Mount paths excluding the first element"
  value       = length(ibm_is_share_mount_target.share_target_sg[*].mount_path) > 1 ? slice(ibm_is_share_mount_target.share_target_sg[*].mount_path, 1, length(ibm_is_share_mount_target.share_target_sg[*].mount_path)) : []
}

output "total_mount_paths" {
  description = "Total Mount paths"
  value       = ibm_is_share_mount_target.share_target_sg[*].mount_path
}

#output "mount_paths_excluding_first" {
#  description = "Mount paths excluding the first element"
#  value       = ibm_is_share_mount_target.share_target_vpc[*].mount_path[1:]
#}

#output "mount_paths_excluding_first" {
#  description = "Mount paths excluding the first element"
#  value       = length(ibm_is_share_mount_target.share_target_sg[*].mount_path) > 1 ? slice(ibm_is_share_mount_target.share_target_sg[*].mount_path, 1, length(ibm_is_share_mount_target.share_target_sg[*].mount_path) - 1) : []
#}

#output "mount_paths_excluding_first" {
#  description = "Mount paths excluding the first element"
#  value = length(ibm_is_share_mount_target.share_target_sg[*].mount_path) > 1 ? slice(ibm_is_share_mount_target.share_target_sg[*].mount_path, 1, length(ibm_is_share_mount_target.share_target_sg[*].mount_path) - 1) : []
#}

#output "mount_paths_excluding_first" {
#  description = "Mount paths excluding the first element"
#  value       = length(ibm_is_share_mount_target.share_target_sg[*].mount_path) > 1 ? tail(ibm_is_share_mount_target.share_target_sg[*].mount_path, length(ibm_is_share_mount_target.share_target_sg[*].mount_path) - 1) : []
#}

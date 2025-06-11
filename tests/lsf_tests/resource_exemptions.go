package tests

// ResourceExemptions contains lists of resources to ignore during Terraform operations
type ResourceExemptions struct {
	Destroys []string // Resources to ignore during destroy operations
	Updates  []string // Resources to ignore during update operations
}

// LSFIgnoreLists contains the standard resource exemptions for LSF cluster tests
var LSFIgnoreLists = ResourceExemptions{
	Destroys: []string{
		// Null resources used for provisioning checks
		"module.landing_zone_vsi.module.hpc.module.check_cluster_status.null_resource.remote_exec[0]",
		"module.landing_zone_vsi.module.hpc.module.check_node_status.null_resource.remote_exec[0]",
		"module.landing_zone_vsi.module.hpc.module.check_node_status.null_resource.remote_exec[1]",
		"module.landing_zone_vsi.module.hpc.module.check_node_status.null_resource.remote_exec[2]",
		"module.check_node_status.null_resource.remote_exec[0]",
		"module.check_node_status.null_resource.remote_exec[1]",
		"module.check_node_status.null_resource.remote_exec[2]",
		"module.check_cluster_status.null_resource.remote_exec[0]",

		// Boot waiting resources
		"module.landing_zone_vsi.module.wait_management_vsi_booted.null_resource.remote_exec[0]",
		"module.landing_zone_vsi.module.wait_management_candidate_vsi_booted.null_resource.remote_exec[0]",
		"module.landing_zone_vsi[0].module.wait_management_vsi_booted.null_resource.remote_exec[0]",
		"module.landing_zone_vsi[0].module.wait_management_candidate_vsi_booted.null_resource.remote_exec[0]",
		"module.landing_zone_vsi[0].module.wait_management_candidate_vsi_booted.null_resource.remote_exec[1]",
		"module.landing_zone_vsi[0].module.wait_worker_vsi_booted[0].null_resource.remote_exec[0]",
		"module.landing_zone_vsi[0].module.wait_worker_vsi_booted[0].null_resource.remote_exec[1]",

		// Configuration resources
		"module.landing_zone_vsi.module.do_management_vsi_configuration.null_resource.remote_exec_script_cp_files[0]",
		"module.landing_zone_vsi.module.do_management_vsi_configuration.null_resource.remote_exec_script_cp_files[1]",
		"module.landing_zone_vsi.module.do_management_vsi_configuration.null_resource.remote_exec_script_new_file[0]",
		"module.landing_zone_vsi.module.do_management_candidate_vsi_configuration.null_resource.remote_exec_script_new_file[0]",
		"module.landing_zone_vsi.module.do_management_candidate_vsi_configuration.null_resource.remote_exec_script_run[0]",
		"module.landing_zone_vsi[0].module.do_management_vsi_configuration.null_resource.remote_exec_script_run[0]",

		// Other temporary resources
		"module.lsf.module.resource_provisioner.null_resource.tf_resource_provisioner[0]",
		"module.landing_zone_vsi[0].module.lsf_entitlement[0].null_resource.remote_exec[0]",
		"module.landing_zone_vsi.module.hpc.module.landing_zone_vsi.module.wait_management_candidate_vsi_booted.null_resource.remote_exec[0]",
		"module.landing_zone_vsi.module.hpc.module.landing_zone_vsi.module.wait_management_vsi_booted.null_resource.remote_exec[0]",
	},

	Updates: []string{
		// File storage resources that can be updated without cluster impact
		"module.file_storage.ibm_is_share.share[0]",
		"module.file_storage.ibm_is_share.share[1]",
		"module.file_storage.ibm_is_share.share[2]",
		"module.file_storage.ibm_is_share.share[3]",
		"module.file_storage.ibm_is_share.share[4]",
	},
}

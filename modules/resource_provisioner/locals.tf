locals {
  schematics_inputs_path = format("/tmp/.schematics/%s/solution_terraform.auto.tfvars.json", var.cluster_prefix)
  backend_inputs_path    = format("/tmp/.schematics/%s/backend.tf", var.cluster_prefix)
  remote_inputs_path     = format("%s/terraform.tfvars.json", "/tmp")
  remote_backend_path    = format("%s/backend.tf", "/tmp")
  deployer_path          = "/opt/ibm"
  remote_terraform_path  = format("%s/terraform-ibm-hpc", local.deployer_path)
  # da_hpc_repo_url        = "github.ibm.com/workload-eng-services/HPCaaS.git"
  da_hpc_repo_url             = "github.com/terraform-ibm-modules/terraform-ibm-hpc.git"
  da_hpc_lsf_repo_tag         = "v4.0.0"
  da_hpc_scale_repo_tag       = "v4.0.0"
  da_hpc_repo_tag             = var.scheduler == "Scale" ? local.da_hpc_scale_repo_tag : local.da_hpc_lsf_repo_tag
  remote_ansible_path         = format("%s/ibm-spectrumscale-cloud-deploy", local.deployer_path)
  scale_cloud_infra_repo_url  = "https://github.com/IBM/ibm-spectrum-scale-install-infra"
  scale_cloud_infra_repo_name = "ibm-spectrum-scale-install-infra"
  scale_cloud_infra_repo_tag  = "scale_hpc"
  products                    = var.scheduler == "Scale" ? "scale" : "lsf"
  ssh_key_file                = "${path.root}/../../solutions/${local.products}/bastion_id_rsa"
  bastion_public_key_content  = var.existing_bastion_instance_name != null ? var.bastion_public_key_content : ""
  safe_hmac_params            = nonsensitive(var.tfstate_cos_hmac_key_params)
  safe_state_bucket           = nonsensitive(var.terraform_state_bucket)
  safe_state_bucket_region    = nonsensitive(var.terraform_state_bucket_region)
}

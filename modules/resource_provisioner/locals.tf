locals {
  schematics_inputs_path      = "/tmp/.schematics/solution_terraform.auto.tfvars.json"
  remote_inputs_path          = format("%s/terraform.tfvars.json", "/tmp")
  deployer_path               = "/opt/ibm"
  remote_terraform_path       = format("%s/terraform-ibm-hpc", local.deployer_path)
  da_hpc_repo_url             = "https://github.com/terraform-ibm-modules/terraform-ibm-hpc.git"
  da_hpc_repo_tag             = "npr-lsf-pr" ###### change it to main in future
  remote_ansible_path         = format("%s/ibm-spectrumscale-cloud-deploy", local.deployer_path)
  scale_cloud_infra_repo_url  = "https://github.com/IBM/ibm-spectrum-scale-install-infra"
  scale_cloud_infra_repo_name = "ibm-spectrum-scale-install-infra"
  scale_cloud_infra_repo_tag  = "scale_hpc"
}

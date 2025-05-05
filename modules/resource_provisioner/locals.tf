locals {
  schematics_inputs_path      = "/tmp/.schematics/solution_terraform.auto.tfvars.json"
  remote_inputs_path          = format("%s/terraform.tfvars.json", "/tmp")
  deployer_path               = "/opt/ibm"
  remote_terraform_path       = format("%s/terraform-ibm-hpc", local.deployer_path)
  da_hpc_repo_url             = "https://github.com/terraform-ibm-modules/terraform-ibm-hpc.git"
  da_hpc_repo_tag             = "JL_4850_develop" ###### change it to main in future
  remote_ansible_path         = format("%s/ibm-spectrumscale-cloud-deploy", local.deployer_path)
  scale_cloud_infra_repo_url  = "https://github.com/jayeshh123/ibm-spectrum-scale-install-infra"
  scale_cloud_infra_repo_name = "ibm-spectrum-scale-install-infra"
  scale_cloud_infra_repo_tag  = "jay_scale_da_api"
  products                    = var.scheduler == "Scale" ? "scale" : "lsf"
  ssh_key_file                = "${path.root}/../../solutions/${local.products}/bastion_id_rsa"
}

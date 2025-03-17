locals {
  schematics_inputs_path = "/tmp/.schematics/solution_terraform.auto.tfvars.json"
  remote_inputs_path     = format("%s/terraform.tfvars.json", "/tmp")
  deployer_path          = "/opt/ibm"
  remote_terraform_path  = format("%s/terraform-ibm-hpc", local.deployer_path)
  da_hpc_repo_url        = "https://github.com/terraform-ibm-modules/terraform-ibm-hpc.git"
  da_hpc_repo_tag        = "develop" ###### change it to main in future
}

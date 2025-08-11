locals {
  deployer_hostentry_playbook_path = format("%s/%s/deployer_host_entry_play.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_hostentry_playbook_path    = format("%s/%s/scale_host_entry_play.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_cluster_hosts              = format("%s/%s/scale_cluster_hosts.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_all_inventory              = format("%s/%s/scale_all_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  remove_hostentry_playbooks_path  = format("%s/%s/remove_host_entry_play.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  dns_names                        = jsonencode(var.domain_names)                    #tfsec:ignore:GEN002
  client_private_key               = format("%s/client_key/id_rsa", var.clone_path)  #tfsec:ignore:GEN002
  compute_private_key              = format("%s/compute_key/id_rsa", var.clone_path) #tfsec:ignore:GEN002
  storage_private_key              = format("%s/storage_key/id_rsa", var.clone_path) #tfsec:ignore:GEN002
  gklm_private_key                 = format("%s/gklm_key/id_rsa", var.clone_path)    #tfsec:ignore:GEN002
}

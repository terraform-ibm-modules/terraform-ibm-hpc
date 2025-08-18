locals {
  deployer_hostentry_playbook_path           = format("%s/%s/deployer_host_entry_play.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_hostentry_playbook_path              = format("%s/%s/scale_host_entry_play.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_cluster_hosts                        = format("%s/%s/scale_cluster_hosts.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_baremetal_prerequesite_vars          = format("%s/%s/scale_baremetal_vars.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_all_inventory                        = format("%s/%s/scale_all_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  remove_hostentry_playbooks_path            = format("%s/%s/remove_host_entry_play.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_baremetal_bootdrive_playbook_path    = format("%s/%s/scale_baremetal_bootdrive.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_baremetal_prerequesite_playbook_path = format("%s/%s/scale_baremetal_prerequesite.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  domain_name_file                           = format("%s/%s/domain_names.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  storage_domain                             = try(var.domain_names.storage, null)
  protocol_domain                            = try(var.domain_names.protocol, null)
  client_private_key                         = format("%s/client_key/id_rsa", var.clone_path)  #tfsec:ignore:GEN002
  compute_private_key                        = format("%s/compute_key/id_rsa", var.clone_path) #tfsec:ignore:GEN002
  storage_private_key                        = format("%s/storage_key/id_rsa", var.clone_path) #tfsec:ignore:GEN002
  gklm_private_key                           = format("%s/gklm_key/id_rsa", var.clone_path)    #tfsec:ignore:GEN002
}

locals {
  normalize_hosts = {
    # groups with string values → wrap into {name=...}
    compute_hosts       = { for k, v in try(var.compute_hosts, {}) : k => { name = v, id = null } }
    compute_mgmnt_hosts = { for k, v in try(var.compute_mgmnt_hosts, {}) : k => { name = v, id = null } }
    client_hosts        = { for k, v in try(var.client_hosts, {}) : k => { name = v, id = null } }
    gklm_hosts          = { for k, v in try(var.gklm_hosts, {}) : k => { name = v, id = null } }
    afm_hosts           = { for k, v in try(var.afm_hosts, {}) : k => { name = v, id = null } }
    protocol_hosts      = { for k, v in try(var.protocol_hosts, {}) : k => { name = v, id = null } }
    storage_hosts       = { for k, v in try(var.storage_hosts, {}) : k => { name = v, id = null } }
    storage_tb_hosts    = { for k, v in try(var.storage_tb_hosts, {}) : k => { name = v, id = null } }
    storage_mgmnt_hosts = { for k, v in try(var.storage_mgmnt_hosts, {}) : k => { name = v, id = null } }

    # groups that already have {id,name}
    storage_bms_hosts    = try(var.storage_bms_hosts, {})
    storage_tb_bms_hosts = try(var.storage_tb_bms_hosts, {})
    afm_bms_hosts        = try(var.afm_bms_hosts, {})
    protocol_bms_hosts   = try(var.protocol_bms_hosts, {})
  }
}

locals {
  scale_all_inventory                         = format("%s/%s/scale_all_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  remove_hostentry_playbooks_path             = format("%s/%s/remove_host_entry_play.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  cluster_health_refresh_playbook_path        = format("%s/%s/scale_cluster_health_refresh.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  encryption_replication_playbook_path        = format("%s/%s/scale_encryption_replication.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  remove_security_outbound_rule_playbook_path = format("%s/%s/remove_security_outbound_rule.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_observability_prerequisite_vars       = format("%s/%s/scale_observability_vars.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  grafana_bridge_automation_playbook_path     = format("%s/%s/scale_grafana_bridge_automation.yml", var.clone_path, "ibm-spectrum-scale-install-infra")
  scale_encryption_servers                    = jsonencode(var.scale_encryption_servers)
  storage_inventory_path                      = format("%s/%s/storage_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")
  compute_inventory_path                      = format("%s/%s/compute_inventory.ini", var.clone_path, "ibm-spectrum-scale-install-infra")

  # Build the list of SG entries to pass to the outbound-rule removal playbook.
  # Only include a SG if its ID is non-empty (compute and client SGs are optional).
  sg_candidates = [
    { sg_id = var.security_group_id, rule_name = "storage-allow-all-outbound" },
    { sg_id = var.compute_security_group_id, rule_name = "compute-allow-all-outbound" },
    { sg_id = var.client_security_group_id, rule_name = "client-allow-all-outbound" },
  ]
  sg_entries_json = jsonencode([
    for entry in local.sg_candidates : entry if entry.sg_id != ""
  ])
}

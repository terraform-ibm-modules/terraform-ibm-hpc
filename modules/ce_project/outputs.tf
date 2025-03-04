output "guid" {
  description = "Code Engine Project GUID"
  value       = var.solution == "hpc" ? shell_script.ce_project[0].output["guid"] : ""
}

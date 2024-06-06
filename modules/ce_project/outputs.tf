output "guid" {
  description = "Code Engine Project GUID"
  value       = shell_script.ce_project.output["guid"]
}

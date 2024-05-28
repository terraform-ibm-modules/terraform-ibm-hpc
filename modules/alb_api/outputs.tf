output "alb_hostname" {
  description = "ALB hostname"
  value       = var.create_load_balancer ? shell_script.alb_api[0].output["hostname"] : ""
}

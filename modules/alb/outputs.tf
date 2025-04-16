output "alb_hostname" {
  description = "ALB hostname"
  value       = var.create_load_balancer ? ibm_is_lb.alb[0].hostname : ""
}
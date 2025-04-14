output "password" {
  description = "The generated random password"
  sensitive   = true
  value       = random_password.generate.result
}
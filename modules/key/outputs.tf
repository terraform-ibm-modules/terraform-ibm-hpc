output "public_key_content" {
  value       = try(tls_private_key.itself.public_key_openssh, "")
  sensitive   = false
  description = "Public key content"
}

output "private_key_content" {
  value       = try(tls_private_key.itself.private_key_pem, "")
  sensitive   = false
  description = "Private key content"
}

output "public_key_content" {
  value       = try(tls_private_key.itself.public_key_openssh, "")
  sensitive   = true
  description = "Public key content"
}

output "private_key_content" {
  value       = try(tls_private_key.itself.private_key_pem, "")
  sensitive   = true
  description = "Private key content"
}

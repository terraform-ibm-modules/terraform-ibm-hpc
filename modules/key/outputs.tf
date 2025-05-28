output "public_key_content" {
  value       = try(tls_private_key.private_key_algorithm.public_key_openssh, "")
  sensitive   = true
  description = "Public key content"
}

output "private_key_content" {
  value       = try(tls_private_key.private_key_algorithm.private_key_pem, "")
  sensitive   = true
  description = "Private key content"
}

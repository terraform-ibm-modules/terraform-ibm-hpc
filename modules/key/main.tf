resource "tls_private_key" "private_key_algorithm" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "write_private_key" {
  count           = var.private_key_path != null ? 1 : 0
  content         = tls_private_key.private_key_algorithm.private_key_pem
  filename        = var.private_key_path
  file_permission = "0600"
}

resource "tls_private_key" "itself" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

data "local_file" "kpclient_cert" {
  depends_on = [null_resource.openssl_commands]
  filename   = "${local.key_protect_path}/${var.resource_prefix}.cert"
}

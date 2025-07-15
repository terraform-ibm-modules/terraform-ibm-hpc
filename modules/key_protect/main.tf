resource "null_resource" "openssl_commands" {
  provisioner "local-exec" {
    command = <<EOT
      # Create a Key_Protect folder if not exists
      mkdir -p "${local.key_protect_path}"
      # Get the Key Protect Server certificate
      openssl s_client -showcerts -connect "${var.vpc_region}.kms.cloud.ibm.com:5696" < /dev/null > "${local.key_protect_path}/Key_Protect_Server.cert"
      # Extract the end date of the certificate
      [ -f "${local.key_protect_path}/Key_Protect_Server.cert" ] &&  END_DATE=$(openssl x509 -enddate -noout -in "${local.key_protect_path}/Key_Protect_Server.cert" | awk -F'=' '{print $2}')
      # Get the current date in GMT
      CURRENT_DATE=$(date -u +"%b %d %T %Y %Z")
      # Calculate the difference in days
      DIFF_DAYS=$(echo $(( ( $(date -ud "$END_DATE" +%s) - $(date -ud "$CURRENT_DATE" +%s) ) / 86400 )))
      # Create a Key Protect Server Root and CA certs
      [ -f "${local.key_protect_path}/Key_Protect_Server.cert" ] && awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' "${local.key_protect_path}/Key_Protect_Server.cert" > "${local.key_protect_path}/Key_Protect_Server_CA.cert"
      [ -f "${local.key_protect_path}/Key_Protect_Server_CA.cert" ] && awk '/-----BEGIN CERTIFICATE-----/{x="${local.key_protect_path}/Key_Protect_Server.chain"i".cert"; i++} {print > x}' "${local.key_protect_path}/Key_Protect_Server_CA.cert"
      [ -f "${local.key_protect_path}/Key_Protect_Server.chain.cert" ] && mv "${local.key_protect_path}/Key_Protect_Server.chain.cert" "${local.key_protect_path}/Key_Protect_Server.chain0.cert"
      # Create a Self Signed Certificates
      [ ! -f "${local.key_protect_path}/${var.resource_prefix}.key" ] && openssl genpkey -algorithm RSA -out "${local.key_protect_path}/${var.resource_prefix}.key"
      [ ! -f "${local.key_protect_path}/${var.resource_prefix}.csr" ] && openssl req -new -key "${local.key_protect_path}/${var.resource_prefix}.key" -out "${local.key_protect_path}/${var.resource_prefix}.csr" -subj "/CN=${var.vpc_storage_cluster_dns_domain}"
      [ ! -f "${local.key_protect_path}/${var.resource_prefix}.cert" ] && openssl x509 -req -days $DIFF_DAYS -in "${local.key_protect_path}/${var.resource_prefix}.csr" -signkey "${local.key_protect_path}/${var.resource_prefix}.key" -out "${local.key_protect_path}/${var.resource_prefix}.cert"
    EOT
  }
}

resource "ibm_kms_key" "scale_key" {
  instance_id  = var.key_protect_instance_id
  key_name     = "key"
  standard_key = false
}

resource "ibm_kms_kmip_adapter" "sclae_kmip_adapter" {
  instance_id = var.key_protect_instance_id
  profile     = "native_1.0"
  profile_data = {
    "crk_id" = ibm_kms_key.scale_key.key_id
  }
  description = "Key Protect adapter"
  name        = format("%s-kp-adapter", var.resource_prefix)
}

resource "ibm_kms_kmip_client_cert" "mycert" {
  instance_id = var.key_protect_instance_id
  adapter_id  = ibm_kms_kmip_adapter.sclae_kmip_adapter.adapter_id
  certificate = data.local_file.kpclient_cert.content
  name        = format("%s-kp-cert", var.resource_prefix)
  depends_on  = [data.local_file.kpclient_cert]
}

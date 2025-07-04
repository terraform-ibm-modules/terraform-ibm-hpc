/*
    Creates IBM Cloud reserved ip for protocol nodes.
*/
# Subnet ID with address, name and auto_delete
resource "ibm_is_subnet_reserved_ip" "itself" {
  for_each = {
    # This assigns a subnet-id to each of the instance
    # iteration.
    for idx, count_number in range(1, var.total_reserved_ips + 1) : idx => {
      sequence_string = tostring(count_number)
      subnet_id       = element(var.subnet_id, idx)
    }
  }

  subnet = each.value.subnet_id
  name   = format("%s-%s-res", var.name, each.value.sequence_string)
}

resource "ibm_dns_resource_record" "a_itself" {
  for_each = {
    for idx, count_number in range(1, var.total_reserved_ips + 1) : idx => {
      name       = element(tolist([for name_details in ibm_is_subnet_reserved_ip.itself : name_details.name]), idx)
      network_ip = element(tolist([for ip_details in ibm_is_subnet_reserved_ip.itself : ip_details.address]), idx)
    }
  }

  instance_id = var.protocol_dns_service_id
  zone_id     = var.protocol_dns_zone_id
  type        = "A"
  name        = each.value.name
  rdata       = each.value.network_ip
  ttl         = 300
  depends_on  = [ibm_is_subnet_reserved_ip.itself]
}

resource "ibm_dns_resource_record" "b_itself" {
  for_each = {
    for idx, count_number in range(1, var.total_reserved_ips + 1) : idx => {
      name       = element(tolist([for name_details in ibm_is_subnet_reserved_ip.itself : var.name]), idx)
      network_ip = element(tolist([for ip_details in ibm_is_subnet_reserved_ip.itself : ip_details.address]), idx)
    }
  }

  instance_id = var.protocol_dns_service_id
  zone_id     = var.protocol_dns_zone_id
  type        = "A"
  name        = each.value.name
  rdata       = each.value.network_ip
  ttl         = 300
  depends_on  = [ibm_is_subnet_reserved_ip.itself]
}

resource "ibm_dns_resource_record" "ptr_itself" {
  for_each = {
    for idx, count_number in range(1, var.total_reserved_ips + 1) : idx => {
      name       = element(tolist([for name_details in ibm_is_subnet_reserved_ip.itself : name_details.name]), idx)
      network_ip = element(tolist([for ip_details in ibm_is_subnet_reserved_ip.itself : ip_details.address]), idx)
    }
  }

  instance_id = var.protocol_dns_service_id
  zone_id     = var.protocol_dns_zone_id
  type        = "PTR"
  name        = each.value.network_ip
  rdata       = format("%s.%s", each.value.name, var.protocol_domain)
  ttl         = 300
  depends_on  = [ibm_dns_resource_record.a_itself]
}

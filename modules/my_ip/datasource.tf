data "external" "my_ipv4" {
  program = ["bash", "-c", "echo '{\"ip\":\"'\"$(curl -4 http://ifconfig.io)\"'\"}'"]
}

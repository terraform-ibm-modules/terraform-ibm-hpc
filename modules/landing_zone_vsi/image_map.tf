locals {
  image_region_map = {
    "hpcaas-lsf10-rhel88-v3" = {
      "us-east" = "r014-4f27c07b-d7d9-4530-838c-46333ce10f2f"
      "eu-de"   = "r010-44df5aba-4f76-4940-909e-0dd305f98bcd"
    },
    "hpcaas-lsf10-rhel88-compute-v2" = {
      "us-east" = "r014-ab4e0a87-4799-40b9-92c5-9efdb0d255df"
      "eu-de"   = "r010-1dc095d3-c358-4767-b3e1-77aa739498b5"
    },
    "hpcaas-lsf10-ubuntu2204-compute-v1" = {
      "us-east" = "r014-2874a5a3-9899-4d21-ba3b-863a65ac2a3c"
      "eu-de"   = "r010-6e221138-123a-488b-a2c1-072d057ec9f8"
    }
  }
}
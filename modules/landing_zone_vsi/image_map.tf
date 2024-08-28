locals {
  image_region_map = {
    "hpcaas-lsf10-rhel88-v10" = {
      "us-east"  = "r014-c425251e-b7b5-479f-b9cf-ef72a0f51b5a"
      "eu-de"    = "r010-ce6dac2b-57e4-4a2f-a77d-8b0e549b2cae"
      "us-south" = "r006-c8fefef3-645d-4b5a-bad0-2250c6ddb627"
    },
    "hpcaas-lsf10-rhel88-compute-v6" = {
      "us-east"  = "r014-f4c0dd0f-3bd0-4e2f-bbda-bbbc75a8c33b"
      "eu-de"    = "r010-0217f13b-e6e5-4500-acd4-c170f111d43f"
      "us-south" = "r006-15514933-925c-4923-85dd-3165dcaa3180"
    },
    "hpcaas-lsf10-ubuntu2204-compute-v6" = {
      "us-east"  = "r014-ab2e8be8-d75c-4040-a337-7f086f3ce153"
      "eu-de"    = "r010-027f5d54-9360-4d1f-821b-583329d63855"
      "us-south" = "r006-628b6dbe-e0d4-4c25-bc0f-f554f5523f2e"
    }
  }
}

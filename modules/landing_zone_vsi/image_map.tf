locals {
  image_region_map = {
    "hpcaas-lsf10-rhel88-v9" = {
      "us-east"  = "r014-d2b18006-c0c4-428f-96f3-e033b970c582"
      "eu-de"    = "r010-3bf3f57e-1985-431d-aefe-e9914ab7919c"
      "us-south" = "r006-7b0aa90b-f52c-44b1-bab7-ccbfae9f1816"
    },
    "hpcaas-lsf10-rhel88-compute-v5" = {
      "us-east"  = "r014-deb34fb1-edbf-464c-9af3-7efa2efcff3f"
      "eu-de"    = "r010-2d04cfff-6f54-45d1-b3b3-7e259083d71f"
      "us-south" = "r006-236ee1f4-38de-4845-b7ec-e2ffa7df5d08"
    },
    "hpcaas-lsf10-ubuntu2204-compute-v5" = {
      "us-east"  = "r014-ecbf4c89-16a3-472e-8bab-1e76d744e264"
      "eu-de"    = "r010-9811d8bf-a7f8-4ee6-8342-e5af217bc513"
      "us-south" = "r006-ed76cb75-f086-48e9-8090-e2dbc411abe7"
    }
  }
}

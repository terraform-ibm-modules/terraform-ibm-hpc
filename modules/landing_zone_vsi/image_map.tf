locals {
  image_region_map = {
    "hpcaas-lsf10-rhel88-v11" = {
      "us-east"  = "r014-d490d82a-30c3-4268-af41-e8f59dd6ff55"
      "eu-de"    = "r010-f4354cdc-4c92-44de-8e4d-982e733733ac"
      "us-south" = "r006-8318fcfd-5db0-4dfd-9b75-455147cc74bc"
    },
    "hpcaas-lsf10-rhel88-compute-v7" = {
      "us-east"  = "r014-075020c3-c5a7-4c34-8ace-099b9dc0561f"
      "eu-de"    = "r010-d7fafe1c-8c42-465f-9619-d9e59c56df69"
      "us-south" = "r006-366873cd-79ca-48be-8a18-3e3290b09970"
    },
    "hpcaas-lsf10-ubuntu2204-compute-v7" = {
      "us-east"  = "r014-e78c5600-7d08-4693-930c-734187fa95ac"
      "eu-de"    = "r010-2bc3c0c9-50cb-4625-bca8-476f0179eea7"
      "us-south" = "r006-5b5f3c5e-05fd-42f9-acfa-1398905e428e"
    }
  }
}

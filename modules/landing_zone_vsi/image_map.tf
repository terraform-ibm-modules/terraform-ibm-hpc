locals {
  image_region_map = {
    "hpcaas-lsf10-rhel88-v7" = {
      "us-east"  = "r014-68a7ad8a-c513-418e-a30c-9a04ce0a144a"
      "eu-de"    = "r010-b392ff76-fb8c-4b0f-9fef-fba89eb3ee5b"
      "us-south" = "r006-86f207dd-7029-4705-9222-0f5499387734"
    },
    "hpcaas-lsf10-rhel88-compute-v5" = {
      "us-east"  = "r014-deb34fb1-edbf-464c-9af3-7efa2efcff3f"
      "eu-de"    = "r010-2d04cfff-6f54-45d1-b3b3-7e259083d71f"
      "us-south" = "r006-236ee1f4-38de-4845-b7ec-e2ffa7df5d08"
    },
    "hpcaas-lsf10-ubuntu2204-compute-v4" = {
      "us-east"  = "r014-b15b5e51-ccb6-40e4-9d6b-d0d47864a8a2"
      "eu-de"    = "r010-39f4de94-2a55-431e-ad86-613c5b23a030"
      "us-south" = "r006-fe0e6afd-4d01-4794-a9ed-dd5353dda482"
    }
  }
}

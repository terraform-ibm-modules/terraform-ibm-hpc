locals {
  image_region_map = {
    "hpcaas-lsf10-rhel88-v6" = {
      "us-east"  = "r014-7c8ff827-42f9-4e52-8ac5-0cabfa83cc08"
      "eu-de"    = "r010-ef5c9c76-88c9-461a-9ea9-ae3483b12463"
      "us-south" = "r006-56948288-f03a-452f-a4e8-13c9523e5aac"
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

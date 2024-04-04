locals {
  image_region_map = {
    "hpcaas-lsf10-rhel88-v3" = {
      "us-east" = "r014-4f27c07b-d7d9-4530-838c-46333ce10f2f"
      "eu-de"   = "r010-44df5aba-4f76-4940-909e-0dd305f98bcd"
    },
    "hpcaas-lsf10-rhel88-v4" = {
      "us-south" = "r006-cd41baee-e2b6-46c0-80e8-a95b24043062"
      "eu-de"    = "r010-01ad0f29-83ff-4338-b2fe-c38ec5219338"
      "us-east"  = "r014-9d14bfcd-0500-4574-a9c9-83062ea523ed"
      "eu-gb"    = "r018-f6cb9448-b548-478e-89e2-977a2bdf0705"
      "jp-osa"   = "r034-f909f2c4-c9fe-4f22-a0fd-275607f7e5b4"
      "br-sao"   = "r042-498f02b6-94ba-41a1-8a97-ef47db19f5e6"
      "au-syd"   = "r026-410237ef-0596-4644-b743-bbb6a7f41ba7"
      "jp-tok"   = "r022-3266b1ee-d77e-4387-b9a8-de9ca05cd306"
    }
    "hpcaas-lsf10-rhel88-compute-v3" = {
      "us-south" = "r006-0640892f-1968-4b40-b57d-c9f5cd169abf"
      "eu-de"    = "r010-87ec2507-8470-4889-8dd3-d3c00f48391c"
      "us-east"  = "r014-6585dbb8-5b28-4de5-9d0b-64cd1ce07627"
      "eu-gb"    = "r018-5b6f1256-9eb2-46e0-8292-5ac2a16719f7"
      "jp-osa"   = "r034-773849e9-9608-415d-baa3-59b30cb6547e"
      "br-sao"   = "r042-020afd51-4ca6-4d00-bd4d-98d2a7778699"
      "au-syd"   = "r026-bd2cb2ca-b40b-470b-9847-98b1a3461049"
      "jp-tok"   = "r022-3c4ded08-c095-457d-b7b4-4330fe624fee"
    },
    "hpcaas-lsf10-ubuntu2204-compute-v2" = {
      "us-south" = "r006-81deb336-0ae4-44b4-92c4-10bd304c5016"
      "eu-de"    = "r010-13a7c58a-bef2-4636-b251-b2086720950e"
      "us-east"  = "r014-080311b0-def6-469d-9335-1dd0f5ee29ff"
      "eu-gb"    = "r018-ec204e4b-cd3b-4f45-ada6-498faa68010d"
      "jp-osa"   = "r034-52b02623-976e-4b48-b2c9-66bed080568f"
      "br-sao"   = "r042-5aa8f150-a2bf-435b-8bde-5ea02e51eab4"
      "au-syd"   = "r026-d75c6c1d-5679-4a8b-884c-e3effee28e27"
      "jp-tok"   = "r022-db5c1b0b-683a-4c82-802e-c4696dcb4f24"
    }
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

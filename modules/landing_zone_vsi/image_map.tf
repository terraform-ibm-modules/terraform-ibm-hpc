locals {
  image_region_map = {
    "hpcaas-lsf10-rhel810-compute-v8" = {
      "eu-gb"    = "r018-fd4a0927-72df-440c-93f9-f6a325ec90b6"
      "eu-de"    = "r010-3b541f40-64ab-41f2-ba96-720fd3862a85"
      "us-east"  = "r014-188b366f-25bb-4545-9bf9-11004bb4a016"
      "us-south" = "r006-a99df2a9-5a28-4ba2-b964-0f7e5fd40ac1"
      "jp-tok"   = "r022-7d1e34af-b876-458a-b4b6-f7b5744ca8db"
      "jp-osa"   = "r034-a085a1b5-7f70-40a1-9d84-172d844dfbbc"
      "au-syd"   = "r026-5b600da8-6c93-42e8-9015-48d220180f3b"
      "br-sao"   = "r042-e8ed8280-b1c1-45ba-9fe2-aa5ece321799"
      "ca-tor"   = "r038-bbb8e69c-ddd0-42ab-bd74-b39904c4adfe"
    },
    "hpcaas-lsf10-ubuntu2204-compute-v8" = {
      "us-east"  = "r014-b8deeb5c-90d7-4c07-80a6-d9b130510661"
      "eu-de"    = "r010-1b56109c-b22c-4fca-91a9-e39e98c8d928"
      "us-south" = "r006-eb1e8993-5455-4b98-8a9d-d6e1fe364c08"
    },
    "hpcaas-lsf10-rhel810-v12" = {
      "us-east"  = "r014-5ae97886-6bcb-4fde-9da3-740a513261a8"
      "eu-de"    = "r010-1c8df3b1-8def-45eb-82ac-ab2db1612bd9"
      "us-south" = "r006-045e03ee-4cfa-4415-a4ec-d8bceadc1bdb"
    },
    "hpc-lsf10-rhel810-v1" = {
      "eu-gb"    = "r018-3e1a8229-1f66-4349-a9ee-fd618f07a233"
      "eu-de"    = "r010-627f3de3-e5e2-4bd1-80db-404fcc6acf3d"
      "us-east"  = "r014-cdd9cf63-b5c6-4811-b1e8-3ae91a4deba9"
      "us-south" = "r006-7a738891-044f-47df-b08d-8d5126c421e7"
      "jp-tok"   = "r022-745149bd-5fba-460a-848b-b1eda44734d4"
      "jp-osa"   = "r034-3813573e-70d8-4943-b635-16dc282b4950"
      "au-syd"   = "r026-a4324f42-992a-4cc8-995e-f613e4d7f550"
      "br-sao"   = "r042-f82a29ba-dedc-429a-a983-7b6aee9f4a37"
      "ca-tor"   = "r038-4e771ac3-3339-403c-946a-95a67b23a929"
    }
  }
}

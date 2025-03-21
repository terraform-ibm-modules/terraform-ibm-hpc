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
    "hpc-lsf10-rhel810-v2" = {
      "eu-es"    = "r050-4f5c092b-aeaf-483c-bcf8-f9d3c39199c6"
      "eu-gb"    = "r018-74ea9522-076f-4b51-b8f3-b11db07b663f"
      "eu-de"    = "r010-8800a619-c9f2-4519-af4c-f6d626825dd5"
      "us-east"  = "r014-2ad1515b-38b9-4b46-8ff1-0a0488590c67"
      "us-south" = "r006-724e700a-d5c3-42e6-9559-8808bd359ef4"
      "jp-tok"   = "r022-e54fad74-7b2f-4ed1-8c2d-b6436f880cf1"
      "jp-osa"   = "r034-43c31e3f-008a-45d0-89b1-fbd8ed51b3fe"
      "au-syd"   = "r026-fcfdd9b4-23e6-445b-bebe-4f9b8cdaa16f"
      "br-sao"   = "r042-6f8cbdf8-bfd9-4127-86b3-b130e1ce2b36"
      "ca-tor"   = "r038-e374450a-c76a-4a3b-9440-4e3787d17221"
    }
  }
}

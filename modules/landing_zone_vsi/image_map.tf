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
      "eu-es"    = "r050-86c03f46-e10a-4edf-8fcf-103845362db9"
      "eu-gb"    = "r018-90675b8a-db1b-4a41-b5a0-f21c04cb7d57"
      "eu-de"    = "r010-dd925c68-d186-406b-a8f7-8d965c60512b"
      "us-east"  = "r014-4bc87a52-d377-43da-a042-aa1fa1629d28"
      "us-south" = "r006-6540f00a-525d-4f62-8a35-f218520b37d2"
      "jp-tok"   = "r022-02a31841-c5ca-4527-a660-d8e5b1cfb29e"
      "jp-osa"   = "r034-c7e76920-e735-4702-b04c-1f2cffe170cb"
      "au-syd"   = "r026-ad5cdb8f-1c44-4267-8969-fe62ac0e93a4"
      "br-sao"   = "r042-b89b9b8c-a934-4f9d-88bc-b9a15866f223"
      "ca-tor"   = "r038-d5992a56-ddd1-4156-a98c-54ecef51ae3d"
    }
  }
}

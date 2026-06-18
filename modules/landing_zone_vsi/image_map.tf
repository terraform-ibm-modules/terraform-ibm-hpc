locals {
  image_region_map = {
    "hpc-lsf-fp15-rhel810-v4" = {
      "eu-es"    = "r050-fb013e69-f5ba-4f6c-a5d0-d5d1e2e889ed"
      "eu-gb"    = "r018-4fc3d325-300d-4557-8449-c9b13cdcebb7"
      "eu-de"    = "r010-9f12bb6e-7358-4e4e-863f-de6a3f463424"
      "us-east"  = "r014-8dfb0a75-7ad3-4713-8731-b9f6fc04a8cf"
      "ca-mon"   = "r058-44303174-edc3-4ad1-a82c-cb0438fd3e8c"
      "us-south" = "r006-fe0bfa0b-ea6c-4409-8dc0-1b78fdc13f07"
      "jp-tok"   = "r022-812a573a-beab-4a89-9f48-eca70e8fd816"
      "jp-osa"   = "r034-40977ba3-4ca5-40d2-a701-1ed992a7c9ed"
      "au-syd"   = "r026-76385e7d-02ef-4411-ab74-b7873cf1b362"
      "br-sao"   = "r042-e613710e-34f3-4a54-a3d1-9a7ccfc08728"
      "ca-tor"   = "r038-419ebcfb-38b2-4685-87c2-112f37ddc361"
    },
    "hpc-lsf-fp15-compute-rhel810-v4" = {
      "eu-es"    = "r050-b9fe14f8-d8fa-439e-b92f-8f03cf0a32fb"
      "eu-gb"    = "r018-89f14dbf-f893-4042-8d23-987f2045e0ec"
      "eu-de"    = "r010-bbbab2df-8d44-4aae-bb06-e345e89dc95e"
      "us-east"  = "r014-9bf38e3a-8147-455d-82f5-c727c9d087b7"
      "ca-mon"   = "r058-7a09f605-00b3-4c33-ab34-8c4c87cd1275"
      "us-south" = "r006-1403a3ef-4857-4d1a-b41c-0c972137f6fc"
      "jp-tok"   = "r022-94f54e0b-bf42-45d9-977b-2dc1c01b4141"
      "jp-osa"   = "r034-d1b2698a-2b6c-42ea-a402-95ac134ff3a4"
      "au-syd"   = "r026-58b0f974-1d6b-4e26-9982-ca8f3864ac66"
      "br-sao"   = "r042-01967af3-9a50-41b1-b5f8-4f36de072a05"
      "ca-tor"   = "r038-c645a3d1-026b-4322-a96a-27e546d54754"
    }
  }
  storage_image_region_map = {
    "hpcc-scale6000-rhel810-v1" = {
      "eu-es"    = "r050-d586cb85-f73c-494e-b996-99dd20e6b627"
      "eu-gb"    = "r018-ba9933df-2879-4514-afb5-30071ace35ac"
      "eu-de"    = "r010-3a429828-d408-4c66-bda0-6dae287a2998"
      "us-east"  = "r014-0286af84-0209-4074-ac61-7d9aaf8d49d3"
      "us-south" = "r006-d003469e-87a5-496c-9b47-58bf644d76b3"
      "jp-tok"   = "r022-1bf416ab-0797-438e-917b-9eed96dbde95"
      "jp-osa"   = "r034-9eba237b-2a97-4ced-948e-862e65ab3f84"
      "au-syd"   = "r026-85e309c1-d9cf-47c9-8e16-55797db07853"
      "br-sao"   = "r042-7b4ee64c-6bcf-40b2-9168-d5163851816e"
      "ca-tor"   = "r038-c335cf82-83d4-4d7f-a1ba-fab40770a444"
    }
  }
  evaluation_image_region_map = {
    "hpcc-scale6000-dev-rhel810" = {
      "eu-es"    = "r050-6eac2073-72ea-451d-91a7-ac1b80c868ac"
      "eu-gb"    = "r018-6f99b7b3-6455-4d83-a299-c9ebf9e88bf4"
      "eu-de"    = "r010-ee6f89ed-6a71-4be3-9f6d-5303ba038db5"
      "us-east"  = "r014-18b03c46-109e-4304-82c9-3351ddb86b3a"
      "us-south" = "r006-45df00de-35c8-42e8-89b9-9045a4e5e13b"
      "jp-tok"   = "r022-e53756df-80a5-4f89-a555-c4a6c3772379"
      "jp-osa"   = "r034-67fdb6c7-28bc-4803-9914-7cd9b455f7bb"
      "au-syd"   = "r026-eb084f68-75ca-4c2a-8882-8aa8c0ee4441"
      "br-sao"   = "r042-6bf1c2d4-a5ca-40bc-9cc0-5b7b515ecb3c"
      "ca-tor"   = "r038-1bb917ea-b4cf-44af-b8bd-1bde3a808d81"
    }
  }
  encryption_image_region_map = {
    "hpcc-scale-gklm4202-v2-5-6" = {
      "eu-es"    = "r050-b64ebc66-4c6f-4406-a395-4719d4d29737"
      "eu-gb"    = "r018-53ed7ae5-8171-45fd-927e-bdc2d3c30421"
      "eu-de"    = "r010-c6bd5fb2-3280-4fc3-83fe-7453685680c7"
      "us-east"  = "r014-5b6ff123-4190-446d-9fcc-bf9db86560a1"
      "us-south" = "r006-1509b12b-af09-422a-9ec3-ad4381832354"
      "jp-tok"   = "r022-20820c22-1e28-4a36-a2e7-172f5904242c"
      "jp-osa"   = "r034-5e9e7992-77ea-4d94-a406-f2ccfbd18615"
      "au-syd"   = "r026-640bffc6-fe12-4190-b959-1bf25b6df951"
      "br-sao"   = "r042-57bb22ab-7ce4-4023-b55b-56f92f3ecff8"
      "ca-tor"   = "r038-e6857a1c-d505-497e-831a-27f0d73f7702"
    }
  }
}

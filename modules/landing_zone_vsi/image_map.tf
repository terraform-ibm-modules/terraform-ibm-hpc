locals {
  image_region_map = {
    "hpc-lsf-fp16-rhel810-v1" = {
      "eu-es"    = "r050-84675e3c-767e-4b79-aace-b7e755f03c46"
      "eu-gb"    = "r018-4ae0d3e5-93b1-4fea-80e2-58dbd3eaa041"
      "eu-de"    = "r010-c683de52-924c-43a1-841b-35c8200e3d80"
      "us-east"  = "r014-8da26f0b-d37d-4346-926d-3cda9fa17957"
      "ca-mon"   = "r058-189e5d11-6d7c-44ca-893f-2f34ac73400d"
      "us-south" = "r006-20a0beaa-9598-4eaf-8409-d49fae1ba979"
      "jp-tok"   = "r022-8c3ce299-705c-4d83-817a-c26fe7504cbc"
      "jp-osa"   = "r034-21c359db-e96b-4063-afaf-056b0616deb9"
      "au-syd"   = "r026-fcf13f9a-46d0-48de-b545-2b65ec2a0b4e"
      "br-sao"   = "r042-484c7865-bf08-4992-b1eb-bc52a70bb424"
      "ca-tor"   = "r038-d5145d04-30bf-4bef-93c4-2745d2410e8b"
    },
    "hpc-lsf-fp16-compute-rhel810-v1" = {
      "eu-es"    = "r050-c6000d0b-7703-4ebb-a8d4-0fed78fad00a"
      "eu-gb"    = "r018-e5ced818-8d00-425d-a875-30c6c351c320"
      "eu-de"    = "r010-a8293f76-b6eb-4fd1-8203-9f9fd8d0321f"
      "us-east"  = "r014-be481c44-75e6-4e1b-baa9-003d970cbfa4"
      "ca-mon"   = "r058-9b0a0fa8-5107-4e7f-949b-62f54217e613"
      "us-south" = "r006-57c9f0ec-5677-49f0-b6bd-8a5cc5f6694a"
      "jp-tok"   = "r022-fc41f5ca-af6e-4fcd-9ff2-e8c5ada33079"
      "jp-osa"   = "r034-9d3d5942-e995-4c6c-8d53-3b66c8376e50"
      "au-syd"   = "r026-4ac0dbd3-05ab-4d13-b881-cda8811193bd"
      "br-sao"   = "r042-70671e61-2c75-45b8-8a27-543b28873821"
      "ca-tor"   = "r038-ca1bf1e8-f081-4d1b-8715-1bd21b3e309b"
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

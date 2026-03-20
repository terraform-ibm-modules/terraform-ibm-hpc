locals {
  image_region_map = {
    "hpc-lsf-fp15-rhel810-v3" = {
      "eu-es"    = "r050-dbfad241-fa72-4fb8-9708-13f597b04ca8"
      "eu-gb"    = "r018-ce9e6351-4474-4a12-981c-08b8e287307a"
      "eu-de"    = "r010-1caed2f0-aeff-4c55-91c4-7e10d512ac87"
      "us-east"  = "r014-91e9a429-9a92-48db-83fd-a712fd22ac5c"
      "ca-mon"   = "r058-795922bb-99cc-42d2-83bd-806a9004913c"
      "us-south" = "r006-c2f03613-830a-4c0a-84a0-27368ebbbaba"
      "jp-tok"   = "r022-f7c6ad40-7048-424a-935c-4a55e57c14ae"
      "jp-osa"   = "r034-37e3861f-b0f4-4454-9b09-d0d709525292"
      "au-syd"   = "r026-ec0d11b5-3f42-4fc9-a640-8985ec63b03b"
      "br-sao"   = "r042-a88a1bfc-71c1-42e8-9d2c-4a5fb3464bc3"
      "ca-tor"   = "r038-0280bae8-00bd-42fe-ade9-e51a6f6011e9"
    },
    "hpc-lsf-fp15-compute-rhel810-v3" = {
      "eu-es"    = "r050-55b2616d-02a1-417d-af8d-684061720fbd"
      "eu-gb"    = "r018-a4eaab06-c46f-442d-a593-ac4ce6d39c33"
      "eu-de"    = "r010-029995e9-664a-4c43-90d6-d63d959c1a2c"
      "us-east"  = "r014-46d47d6b-2f24-4740-be24-2f49f54468b5"
      "ca-mon"   = "r058-6a0263d4-3e11-4a5a-a62b-2eb84681632a"
      "us-south" = "r006-4ada53ed-6520-4fcc-aa2d-e1d952210297"
      "jp-tok"   = "r022-a5f85b9e-6b3d-484e-98f2-bb88c6ea1778"
      "jp-osa"   = "r034-8d8277a1-61c0-49a6-b72b-116f021de83a"
      "au-syd"   = "r026-834da9ee-a6a7-40d3-8309-843988b6dbaa"
      "br-sao"   = "r042-4e7672a9-4c87-4ea9-a797-90d81b0db8a7"
      "ca-tor"   = "r038-3c20ae7a-9c8a-44fb-aae1-f42db5fdb3e1"
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
    "hpcc-scale-gklm4202-v2-5-4" = {
      "eu-es"    = "r050-dd558a94-5bba-46b8-94cb-a0470d075db7"
      "eu-gb"    = "r018-0176641e-0318-4123-88d5-3898b7ee16f0"
      "eu-de"    = "r010-0e784645-8fee-4946-9af9-69be76b248c9"
      "us-east"  = "r014-c84a4f0a-7d28-4075-9620-d014ab1c8652"
      "us-south" = "r006-d5285daf-bbbd-4a94-acd7-408afcc83aec"
      "jp-tok"   = "r022-4107746c-d6fe-4960-ba2c-1517fbd9708f"
      "jp-osa"   = "r034-a1b1c94c-ad6f-443f-98ac-56d6c03cc01a"
      "au-syd"   = "r026-dce5f0aa-16b4-431a-9cd8-9e2afa9a7fa7"
      "br-sao"   = "r042-17855508-4b88-4765-8d1e-6df94879be2f"
      "ca-tor"   = "r038-bc4acdb3-dd12-49e6-b540-71a757e05747"
    }
  }
}

locals {
  image_region_map = {
    "hpc-lsf-fp15-rhel810-v2" = {
      "eu-es"    = "r050-bb9be81c-7026-4b53-9768-b46fe6ff35af"
      "eu-gb"    = "r018-d85fbab9-5573-4a25-8cd9-b584e0266ed3"
      "eu-de"    = "r010-b5259da3-11f9-434d-87f9-0eed1030f593"
      "us-east"  = "r014-1dffabd0-bb20-4c97-b73a-3a745ccfa53d"
      "us-south" = "r006-829c9fbc-ecb6-4f3d-be37-1f652d26ec58"
      "jp-tok"   = "r022-1c956e0e-17e0-4ce3-833b-d79173d68fe0"
      "jp-osa"   = "r034-7a3733eb-c2eb-4e8e-8b10-4b5bc97331c3"
      "au-syd"   = "r026-4d4d012d-a023-4a32-9a58-fe3b0903be7a"
      "br-sao"   = "r042-7d242646-c928-4eae-8176-b6a4c6aad06b"
      "ca-tor"   = "r038-023f8697-5b44-469e-a021-6898b46ea0a5"
      "ca-mon"   = "r058-e952898e-71cf-4921-8e3c-1e2b00382f07"
    },
    "hpc-lsf-fp15-compute-rhel810-v2" = {
      "eu-es"    = "r050-91d88518-bc52-42f4-a794-f64e9d0e9fac"
      "eu-gb"    = "r018-923c06c7-f077-44b7-9ed2-7d9817d9df26"
      "eu-de"    = "r010-2dd07456-e9ad-4b39-a131-ad786fb1f725"
      "us-east"  = "r014-f464db9b-5951-48ab-908d-8d36614ac086"
      "us-south" = "r006-cb59a6b6-7a58-489b-905c-47ca13f2e60b"
      "jp-tok"   = "r022-1026bca9-163d-4852-a071-7481ebc19255"
      "jp-osa"   = "r034-5551a235-92eb-4316-98e3-5b100b7563c8"
      "au-syd"   = "r026-30a9c1d9-1803-4cf2-9175-bab4f7866f77"
      "br-sao"   = "r042-1f4b2fa5-eb39-472c-acd9-96cba25d46ab"
      "ca-tor"   = "r038-bebb2cdc-530a-4d37-ada7-f8f0fbb17a5f"
      "ca-mon"   = "r058-12b6c1f4-1377-478d-ba39-bd4b38a94e8b"
    },
    "hpc-lsf-fp14-rhel810-v1" = {
      "eu-es"    = "r050-12a3533c-5fa1-4bcc-8765-7150a06e122e"
      "eu-gb"    = "r018-3ef87e4e-0f46-424a-b623-fa25215094c0"
      "eu-de"    = "r010-48e5560b-4d34-43ca-b824-2d85513f3188"
      "us-east"  = "r014-3719a4e2-6746-4eaf-844a-c3721b7c6d32"
      "us-south" = "r006-e720ec63-5e8c-46ce-b7a2-51c454e64099"
      "jp-tok"   = "r022-917ce78b-dacf-4008-b6c0-4058bf59a5b4"
      "jp-osa"   = "r034-507fb655-4164-45b8-b1d7-f6cb2fbeafc9"
      "au-syd"   = "r026-01900450-7314-42ea-aee3-acf5179300c0"
      "br-sao"   = "r042-bb407137-93cf-4ec7-aa77-4702896fff97"
      "ca-tor"   = "r038-6683403d-1cf5-4f39-a96f-c8cbb2314ad5"
    },
    "hpc-lsf-fp14-compute-rhel810-v1" = {
      "eu-es"    = "r050-d2ad9625-1668-4b2c-a8bb-6ef14678d3ed"
      "eu-gb"    = "r018-f1059503-27ec-44d4-a981-21be6225520a"
      "eu-de"    = "r010-8115b1f6-912e-4b55-89f1-e448c397115e"
      "us-east"  = "r014-5108884c-011b-4473-b585-0d43309c37e3"
      "us-south" = "r006-68c6af72-1abf-4d13-bca1-4f42be5d2c70"
      "jp-tok"   = "r022-1932c5ec-b5a6-4262-aa56-6c6257c8297f"
      "jp-osa"   = "r034-50be9bd9-9623-4ffc-8ce7-aab66f674137"
      "au-syd"   = "r026-11aee148-c938-4524-91e6-8e6da5933a42"
      "br-sao"   = "r042-5cb62448-e771-4caf-a556-28fdf88acab9"
      "ca-tor"   = "r038-fa815ec1-d52e-42b2-8221-5b8c2145a248"
    },
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

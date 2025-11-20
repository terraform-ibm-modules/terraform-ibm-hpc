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
    "hpcc-scale5232-rhel810-v1" = {
      "eu-es"    = "r050-7f28959f-74a4-4ad7-be30-8107da85406f"
      "eu-gb"    = "r018-5286d07b-527f-49a2-b0a7-2c88278349e8"
      "eu-de"    = "r010-1e558d55-bc2e-4e96-9164-b4b1139ba06b"
      "us-east"  = "r014-8befe151-c36d-4056-9955-3480210adf98"
      "us-south" = "r006-7ab41080-5af0-47e5-ad44-abc18589197a"
      "jp-tok"   = "r022-d60e9e5f-264d-4e37-9fc0-9ad6270a054e"
      "jp-osa"   = "r034-eac88b73-0978-4340-9188-e28e99aeae2a"
      "au-syd"   = "r026-221f1bb0-1ba3-40c3-a83f-59334a2fda4b"
      "br-sao"   = "r042-e3d377a0-69f6-4079-9cbe-021021fb4a84"
      "ca-tor"   = "r038-73809daf-d414-4319-bc46-1bdd26a8e85d"
    }
  }
  evaluation_image_region_map = {
    "hpcc-scale5232-dev-rhel810" = {
      "eu-es"    = "r050-eb14661e-8290-4c03-a198-3e65a1b17a6b"
      "eu-gb"    = "r018-46ec71d2-2137-48c1-b348-a2ff0a671d91"
      "eu-de"    = "r010-cf5e0560-cbbf-43a6-9ba7-39fb4d4e82ff"
      "us-east"  = "r014-27ceeecc-c5bc-461e-a687-11e5b843274d"
      "us-south" = "r006-12668685-f580-4cc8-86c5-335f1a979278"
      "jp-tok"   = "r022-bfe30f3f-c68f-4f61-ba90-7fbaa1a29665"
      "jp-osa"   = "r034-320617e2-b565-4843-bd8d-9f4bd2dd4641"
      "au-syd"   = "r026-ad179ec6-37a0-4d0c-9816-d065768414cf"
      "br-sao"   = "r042-ed759187-cd74-4d13-b475-bd0ed443197b"
      "ca-tor"   = "r038-90ca620e-5bf9-494e-a6ba-7e5ee663a54b"
    }
  }
  encryption_image_region_map = {
    "hpcc-scale-gklm4202-v2-5-3" = {
      "eu-es"    = "r050-99e1114e-cccb-4ce3-9ccb-98cb33851ea7"
      "eu-gb"    = "r018-c5a2e862-48ff-4dee-95a8-5a8976af4007"
      "eu-de"    = "r010-ec37acc8-131f-4156-af6a-659c7dda3686"
      "us-east"  = "r014-df6816f2-f636-427d-afb6-26e4ebc0760d"
      "us-south" = "r006-2ab3cbd7-d554-454d-b117-e26efa67c811"
      "jp-tok"   = "r022-2e1db131-fac6-46d1-8cd5-54811a7fb61e"
      "jp-osa"   = "r034-10c7ad32-07c8-4524-8d9e-f4ed6eece005"
      "au-syd"   = "r026-ea22104d-ca12-4e8f-94f3-1325848534e0"
      "br-sao"   = "r042-0b9176fa-12df-4d41-9711-465c11967dac"
      "ca-tor"   = "r038-56e22958-fc5b-4085-9760-a19132d9a0e4"
    }
  }
}

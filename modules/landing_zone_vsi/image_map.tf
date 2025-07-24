locals {
  image_region_map = {
    "hpc-lsf-fp15-rhel810-v1" = {
      "eu-es"    = "r050-deeeb734-2523-4aff-96e3-2be8d2b0d634"
      "eu-gb"    = "r018-8edcd9a1-dbca-462f-bf74-017c15ca4b71"
      "eu-de"    = "r010-394c5295-1704-4066-b57e-ae9bca1968de"
      "us-east"  = "r014-1777cdcb-8a68-4ef0-becf-84ec0d2e9a26"
      "us-south" = "r006-40caf671-28a8-42c5-b83e-b2ba3ceb86af"
      "jp-tok"   = "r022-01531301-d100-44ba-b1a3-12e7c8d65469"
      "jp-osa"   = "r034-ac455775-c667-4d3e-b281-9ef845080599"
      "au-syd"   = "r026-eff4d59c-5006-46cc-8b03-60514f763a87"
      "br-sao"   = "r042-1e1bbeeb-3ef7-4f7a-a44c-9f50609bb538"
      "ca-tor"   = "r038-bb9fcdb7-d200-4cdd-af04-6848007c9cb2"
    },
    "hpc-lsf-fp15-compute-rhel810-v1" = {
      "eu-es"    = "r050-f0608e39-9dcf-4aca-9e92-7719474b3e86"
      "eu-gb"    = "r018-db8b97a8-6f87-4cf7-a044-847da6ab5c59"
      "eu-de"    = "r010-957efd6b-e7b3-4249-8644-6184f1531915"
      "us-east"  = "r014-5fdd6a25-5943-4084-9c57-b900a80579a3"
      "us-south" = "r006-5c0e462a-679c-4a18-81a5-0fe036f483a3"
      "jp-tok"   = "r022-8087a984-8912-42ff-9576-c5cab8edda3a"
      "jp-osa"   = "r034-728d1f12-7842-412c-97a0-9deb66c23962"
      "au-syd"   = "r026-f957ed22-9565-441c-bce6-f716360e02ea"
      "br-sao"   = "r042-7bf7d508-a7b1-4434-ae6a-6986f7042d4e"
      "ca-tor"   = "r038-a658da44-f1b4-4e02-826a-38b16e6ae98a"
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
    "hpcc-scale5232-rhel810-v1" = {
      "jp-tok" = "r022-f2349717-ac91-4dda-8096-fc0c7377301a"
    }
  }
  storage_image_region_map = {
    "hpcc-scale5232-rhel810-v1" = {
      "jp-tok" = "r022-f2349717-ac91-4dda-8096-fc0c7377301a"
    }
  }
}

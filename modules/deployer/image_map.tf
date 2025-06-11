locals {
  image_region_map = { ### Image IDs need to be updated here ###
    "hpc-lsf-fp15-deployer-rhel810-v1" = {
      "eu-es"    = "r050-deeeb734-2523-4aff-96e3-2be8d2b0d634"
      "eu-gb"    = "r018-8edcd9a1-dbca-462f-bf74-017c15ca4b71"
      "eu-de"    = "r010-00629ef3-324c-4651-a7a7-76830d2ad660"
      "us-east"  = "r014-1777cdcb-8a68-4ef0-becf-84ec0d2e9a26"
      "us-south" = "r006-40caf671-28a8-42c5-b83e-b2ba3ceb86af"
      "jp-tok"   = "r022-dd715ea3-d2dc-4936-bff0-51c9cd63b3a9"
      "jp-osa"   = "r034-ac455775-c667-4d3e-b281-9ef845080599"
      "au-syd"   = "r026-eff4d59c-5006-46cc-8b03-60514f763a87"
      "br-sao"   = "r042-1e1bbeeb-3ef7-4f7a-a44c-9f50609bb538"
      "ca-tor"   = "r038-bb9fcdb7-d200-4cdd-af04-6848007c9cb2"
    },
    "hpc-lsf-fp14-deployer-rhel810-v1" = {
      "eu-es"    = "r050-f0608e39-9dcf-4aca-9e92-7719474b3e86"
      "eu-gb"    = "r018-db8b97a8-6f87-4cf7-a044-847da6ab5c59"
      "eu-de"    = "r010-c5b5f7d9-bc3e-4e18-9724-f682ccfef617"
      "us-east"  = "r014-5fdd6a25-5943-4084-9c57-b900a80579a3"
      "us-south" = "r006-5c0e462a-679c-4a18-81a5-0fe036f483a3"
      "jp-tok"   = "r022-b02c8618-ea8f-42bf-854a-da5822ee3cb5"
      "jp-osa"   = "r034-728d1f12-7842-412c-97a0-9deb66c23962"
      "au-syd"   = "r026-f957ed22-9565-441c-bce6-f716360e02ea"
      "br-sao"   = "r042-7bf7d508-a7b1-4434-ae6a-6986f7042d4e"
      "ca-tor"   = "r038-a658da44-f1b4-4e02-826a-38b16e6ae98a"
    }
  }
}

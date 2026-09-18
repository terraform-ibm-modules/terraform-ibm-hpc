locals {
  image_region_map = {
    "hpc-lsf-fp16-deployer-rhel810-v1" = {
      "eu-es"    = "r050-e131056b-dcf3-4d2f-913b-c4b809db856e"
      "eu-gb"    = "r018-0e167019-9994-4a5e-a1f7-229ff71b2d5a"
      "eu-de"    = "r010-8288d3e3-e0b6-43b6-9e85-c91743cc830d"
      "us-east"  = "r014-e8343421-fff5-4487-9217-e387dd8d10b2"
      "ca-mon"   = "r058-bbd4c0f7-4890-4e80-84bf-ee1765ca0b38"
      "us-south" = "r006-927746a9-d664-4a82-bddc-78c804ffa29c"
      "jp-tok"   = "r022-0b9dd9f3-7d9c-4430-8a45-d3342d489c5c"
      "jp-osa"   = "r034-37b8db14-d013-47c2-b85f-7d0d4035d11b"
      "au-syd"   = "r026-d87fef00-3b68-47ef-a9d6-ff40d2be32c4"
      "br-sao"   = "r042-e5d0e998-c7d5-461d-804c-bdf0fd31fa6a"
      "ca-tor"   = "r038-f0b4f64d-85f7-4049-89cb-971bbe8cdaf2"
    },
    "hpcc-scale-deployer-v2" = {
      "eu-es"    = "r050-8dd39af9-61e0-47eb-a51c-1aacb0194f5a"
      "eu-gb"    = "r018-0917f64b-47d8-4eea-8507-836ba97514e4"
      "eu-de"    = "r010-9618ddb7-b22c-4b34-b7e1-01628e284110"
      "us-east"  = "r014-cde1ba22-520e-4dda-830f-f22a2e5b3cc0"
      "us-south" = "r006-843aae28-750d-4e04-8690-b162bceefc3c"
      "jp-tok"   = "r022-badefd3f-2c2b-4c3d-a017-ccea8c642482"
      "jp-osa"   = "r034-3934f22f-05a6-465c-adf3-5aa6ab88916b"
      "au-syd"   = "r026-0bce92f0-945e-4900-8226-0b551938736b"
      "br-sao"   = "r042-7965adfa-fb7f-490b-8796-d2fc71b2688f"
      "ca-tor"   = "r038-cfe2e5f0-4bfb-4a34-9d04-85127c4c5219"
    }
  }
}

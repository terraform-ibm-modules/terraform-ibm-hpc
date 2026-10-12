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
    "hpcc-scale-deployer-v3" = {
      "eu-es"    = "r050-641b07e3-6b90-4cf3-855a-1249c773d4f4"
      "eu-gb"    = "r018-72a5c22b-5916-4045-9d8c-7d18c6c47667"
      "eu-de"    = "r010-f9a8fac3-dd32-471a-b1f6-474038898796"
      "us-east"  = "r014-765c0818-42fe-4e6c-a298-3ab60a545862"
      "us-south" = "r006-a5c93022-a60d-4428-a0c7-47e6ca140e0a"
      "jp-tok"   = "r022-8b316fc4-e3a2-4f5a-b2a4-aad966b0b8c1"
      "jp-osa"   = "r034-3b680de6-b61c-43d3-b961-b444af266265"
      "au-syd"   = "r026-7907f67c-241f-44f2-aa29-86f418ffadb2"
      "br-sao"   = "r042-ace14b0e-fa0e-4e90-bd2d-2fa6591af112"
      "ca-tor"   = "r038-8dbe0100-6bd1-482b-bd56-25d1ac32943a"
    }
  }
}

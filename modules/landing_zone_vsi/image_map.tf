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
    "hpcc-scale6000-rhel96-v1" = {
      "eu-es"    = "r050-0b0137dd-b785-46d3-9290-d5d99127356b"
      "eu-gb"    = "r018-f3b12456-7c45-4836-825b-44e682a813c5"
      "eu-de"    = "r010-b8c2454d-6ad4-4dfe-a000-65c899e8cc3f"
      "us-east"  = "r014-59c0f602-7032-453a-8a30-31ce00e36532"
      "us-south" = "r006-51a01df1-69ea-4cda-915b-475160acfd7b"
      "jp-tok"   = "r022-5259e884-97dc-46d7-b66c-d29b6c211304"
      "jp-osa"   = "r034-b05ee02b-320b-4d2c-a765-e78c8ec8af4e"
      "au-syd"   = "r026-c81f421c-8187-4c81-9033-faf0eaa90e6a"
      "br-sao"   = "r042-eb1a1661-faf2-4d27-b26e-7f8faae3ebb2"
      "ca-tor"   = "r038-91454243-d642-4a14-b744-e04e91f34c4f"
    }
  }
  evaluation_image_region_map = {
    "hpcc-scale6000-dev-rhel810" = {
      "eu-es"    = "r050-aba96959-0605-4142-8a02-4bd500bad55a"
      "eu-gb"    = "r018-cb7f6ba7-428b-428c-a935-8ca98440432c"
      "eu-de"    = "r010-bd3c9ecb-f1a1-4307-aa24-c30a87ed8488"
      "us-east"  = "r014-28316f68-4c91-4a70-9ba6-5a394ab6b004"
      "us-south" = "r006-25fc1250-aa40-43d4-a3b8-992274f01df1"
      "jp-tok"   = "r022-37fa2d03-f291-4060-b4cc-13b833bacdf0"
      "jp-osa"   = "r034-4a57e255-9586-4818-adaf-f096b981baff"
      "au-syd"   = "r026-26d303ca-ff9b-47f0-9771-1aa8752c1aa9"
      "br-sao"   = "r042-3300bf3d-4435-4d0f-9296-538a92278d53"
      "ca-tor"   = "r038-06793a91-733b-4bf2-b9bf-52decff16fea"
    }
  }
  encryption_image_region_map = {
    "hpcc-scale-gklm4202-v3" = {
      "eu-es"    = "r050-bec4c2c4-ddeb-4054-a8c0-6fce1057822c"
      "eu-gb"    = "r018-f765926d-6d0d-499d-a51d-e4afd9b05ce6"
      "eu-de"    = "r010-51153b4a-aa28-4d3d-b6a3-7bb8e3dd6449"
      "us-east"  = "r014-62720c8e-6c4e-4b80-9b12-ff47b7a1cfdd"
      "us-south" = "r006-5dfad25a-c4c1-4c9a-97b7-49ff2983a696"
      "jp-tok"   = "r022-380fca86-5ec6-4300-a9cf-75c0d16202f4"
      "jp-osa"   = "r034-a020da5b-2e79-45c5-9d77-c0e3c0fdd16a"
      "au-syd"   = "r026-7d9f040f-830d-482d-9151-0ee0660f26b3"
      "br-sao"   = "r042-045ad982-9078-47c8-821e-c339c4c879ab"
      "ca-tor"   = "r038-1ae27847-eced-4364-898b-77ebbdc64351"
    }
  }
}

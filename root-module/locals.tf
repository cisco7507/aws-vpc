locals {
  region = "us-west-2"
}

locals {
  azs = ["${local.region}a", "${local.region}b"]
}

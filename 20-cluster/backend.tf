terraform {
  required_version = ">= 1.12"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.25.0"
    }
  }
  backend "oci" {
    bucket    = "tfstate-inference-poc"
    namespace = "idz7dmnfnz71"
    key       = "20-cluster/terraform.tfstate"
    region    = "us-ashburn-1"

    auth                = "APIKey"
    config_file_profile = "DEFAULT"
  }
}

provider "oci" {
  region = var.region
}

data "terraform_remote_state" "network" {
  backend = "oci"
  config = {
    bucket    = "tfstate-inference-poc"
    namespace = "idz7dmnfnz71"
    key       = "10-network/terraform.tfstate"
    region    = "us-ashburn-1"
  }
}

locals {
  subnets = data.terraform_remote_state.network.outputs.subnet_ids
  nsgs    = data.terraform_remote_state.network.outputs.nsg_ids
}

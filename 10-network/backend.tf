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
    key       = "10-network/terraform.tfstate"
    region    = "us-ashburn-1"

    auth                = "APIKey"
    config_file_profile = "DEFAULT"
  }
}

provider "oci" {
  region = var.region
}

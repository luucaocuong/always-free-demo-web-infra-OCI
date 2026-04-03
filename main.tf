terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "oci" {
  region = var.region
}

locals {
  name_prefix = var.project_name

  # Pull the first two ADs in the region for HA placement
  ad_names = [
    data.oci_identity_availability_domains.ads.availability_domains[0].name
  ]

  common_tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

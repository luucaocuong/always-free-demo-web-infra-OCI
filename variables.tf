# ─────────────────────────────────────────────
# OCI Authentication
# ─────────────────────────────────────────────
variable "region" { default = "ap-tokyo-1" }

# ─────────────────────────────────────────────
# Project
# ─────────────────────────────────────────────
variable "compartment_ocid" {}
variable "project_name" { default = "webdemo" }


# ─────────────────────────────────────────────
# Compute
# ─────────────────────────────────────────────
variable "instance_shape" { default = "VM.Standard.A1.Flex" }
variable "instance_ocpus" { default = 1 }
variable "instance_memory_gb" { default = 4 }
variable "instance_pool_size" { default = 2 }

# Base image: Oracle Linux 8 (find latest in your region via OCI console)
variable "instance_image_ocid" {}

variable "ssh_public_key" {}

# ─────────────────────────────────────────────
# MySQL
# ─────────────────────────────────────────────
variable "mysql_admin_username" { default = "admin" }
variable "mysql_admin_password" {
  sensitive = true
}
variable "mysql_shape" { default = "MySQL.Free" }

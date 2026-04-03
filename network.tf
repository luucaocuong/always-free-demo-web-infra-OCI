# ─────────────────────────────────────────────
# VCN
# ─────────────────────────────────────────────
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.name_prefix}-vcn"
  cidr_block     = "10.0.0.0/16"
  dns_label      = local.name_prefix
  freeform_tags  = local.common_tags
}

# ─────────────────────────────────────────────
# Gateways
# ─────────────────────────────────────────────
resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name_prefix}-igw"
  enabled        = true
  freeform_tags  = local.common_tags
}

resource "oci_core_nat_gateway" "nat" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name_prefix}-nat"
  freeform_tags  = local.common_tags
}

# ─────────────────────────────────────────────
# Route Tables
# ─────────────────────────────────────────────
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name_prefix}-rt-public"
  freeform_tags  = local.common_tags

  route_rules {
    network_entity_id = oci_core_internet_gateway.igw.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name_prefix}-rt-private"
  freeform_tags  = local.common_tags

  route_rules {
    network_entity_id = oci_core_nat_gateway.nat.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

# ─────────────────────────────────────────────
# Security Lists
# ─────────────────────────────────────────────

# Public subnet: allow HTTP/HTTPS inbound, all outbound
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name_prefix}-sl-public"
  freeform_tags  = local.common_tags

  ingress_security_rules {
    protocol  = "6" # TCP
    source    = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol  = "6"
    source    = "0.0.0.0/0"
    stateless = false
    tcp_options {
      min = 443
      max = 443
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }
}

# Private (app) subnet: allow traffic from LB subnet + outbound
resource "oci_core_security_list" "private_app" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name_prefix}-sl-app"
  freeform_tags  = local.common_tags

  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.0.0/16" 
    stateless = false
    tcp_options { 
      min = 8080
      max = 8080 
    }
  }
  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.0.0/16" 
    stateless = false
    tcp_options { 
      min = 22
      max = 22
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }
}

# DB subnet: allow MySQL from app subnet only
resource "oci_core_security_list" "private_db" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.name_prefix}-sl-db"
  freeform_tags  = local.common_tags

  ingress_security_rules {
    protocol  = "6"
    source    = "10.0.2.0/24" # App subnet CIDR
    stateless = false
    tcp_options { 
      min = 3306
      max = 3306
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
    stateless   = false
  }
}

# ─────────────────────────────────────────────
# Subnets
# ─────────────────────────────────────────────

# Public subnet — Load Balancer
resource "oci_core_subnet" "public_lb" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.main.id
  display_name      = "${local.name_prefix}-subnet-lb"
  cidr_block        = "10.0.1.0/24"
  dns_label         = "lb"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.public.id]
  freeform_tags     = local.common_tags
}

# Private subnet — App instances
resource "oci_core_subnet" "private_app" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  display_name               = "${local.name_prefix}-subnet-app"
  cidr_block                 = "10.0.2.0/24"
  dns_label                  = "app"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private_app.id]
  freeform_tags              = local.common_tags
}

# Private subnet — MySQL DB
resource "oci_core_subnet" "private_db" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  display_name               = "${local.name_prefix}-subnet-db"
  cidr_block                 = "10.0.3.0/24"
  dns_label                  = "db"
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private_db.id]
  freeform_tags              = local.common_tags
}

# ─────────────────────────────────────────────
# Cloud-init user data (bootstrap script)
# Installs Node.js app that connects to MySQL
# ─────────────────────────────────────────────
locals {
  user_data = base64encode(templatefile("${path.module}/cloud-init.sh", {
    db_host     = oci_mysql_mysql_db_system.main.endpoints[0].ip_address
    db_port     = "3306"
    db_name     = "itemsdb"
    db_user     = var.mysql_admin_username
    db_password = var.mysql_admin_password
  }))
}

# ─────────────────────────────────────────────
# Instance Configuration (launch template)
# ─────────────────────────────────────────────
resource "oci_core_instance_configuration" "app" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.name_prefix}-instance-config"
  freeform_tags  = local.common_tags
  lifecycle {
    create_before_destroy = true
  }
  instance_details {
    instance_type = "compute"

    launch_details {
      compartment_id = var.compartment_ocid
      display_name   = "${local.name_prefix}-app"
      shape          = var.instance_shape
      freeform_tags  = local.common_tags

      shape_config {
        ocpus         = var.instance_ocpus
        memory_in_gbs = var.instance_memory_gb
      }

      source_details {
        source_type = "image"
        image_id    = var.instance_image_ocid
      }

      create_vnic_details {
        subnet_id             = oci_core_subnet.private_app.id
        assign_public_ip      = false
        nsg_ids               = []
      }

      metadata = {
        ssh_authorized_keys = var.ssh_public_key
        user_data           = local.user_data
      }
    }
  }

  depends_on = [oci_mysql_mysql_db_system.main]
}

# ─────────────────────────────────────────────
# Instance Pool (2 instances across 2 ADs)
# ─────────────────────────────────────────────
resource "oci_core_instance_pool" "app" {
  compartment_id            = var.compartment_ocid
  display_name              = "${local.name_prefix}-pool"
  instance_configuration_id = oci_core_instance_configuration.app.id
  size                      = var.instance_pool_size
  freeform_tags             = local.common_tags

  placement_configurations {
    availability_domain = local.ad_names[0]
    primary_subnet_id   = oci_core_subnet.private_app.id
  }


  # Attach to load balancer backend set
  load_balancers {
    load_balancer_id = oci_load_balancer_load_balancer.main.id
    backend_set_name = oci_load_balancer_backend_set.app.name
    port             = 8080
    vnic_selection   = "PrimaryVnic"
  }

  depends_on = [
    oci_load_balancer_backend_set.app,
    oci_core_instance_configuration.app,
  ]
}

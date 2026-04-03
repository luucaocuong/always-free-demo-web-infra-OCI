resource "oci_mysql_mysql_db_system" "main" {
  compartment_id      = var.compartment_ocid
  display_name        = "${local.name_prefix}-mysql"
  availability_domain = local.ad_names[0]
  subnet_id           = oci_core_subnet.private_db.id
  shape_name          = var.mysql_shape
  freeform_tags       = local.common_tags

  admin_username = var.mysql_admin_username
  admin_password = var.mysql_admin_password

  data_storage_size_in_gb = 50

  dynamic "backup_policy" {
    for_each = var.mysql_shape == "MySQL.Free" ? [] : [1]
    content {
      is_enabled        = true
      retention_in_days = 7
      window_start_time = "02:00"
    }
  }

  maintenance {
    window_start_time = "sun 03:00"
  }
}
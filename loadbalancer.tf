# ─────────────────────────────────────────────
# Public Load Balancer
# ─────────────────────────────────────────────
resource "oci_load_balancer_load_balancer" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "${local.name_prefix}-lb"
  shape          = "flexible" # Always Free uses the flexible shape now
  subnet_ids     = [oci_core_subnet.public_lb.id]
  is_private     = false

  shape_details {
    # Both must be 10 for the Always Free slot
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 10
  }
}

# ─────────────────────────────────────────────
# Backend Set
# ─────────────────────────────────────────────
resource "oci_load_balancer_backend_set" "app" {
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  name             = "app-backend-set"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "HTTP"
    port              = 8080
    url_path          = "/health"
    interval_ms       = 10000
    timeout_in_millis = 3000
    retries           = 3
    return_code       = 200
  }
}

# ─────────────────────────────────────────────
# HTTP Listener (port 80)
# ─────────────────────────────────────────────
resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.main.id
  name                     = "http-listener"
  default_backend_set_name = oci_load_balancer_backend_set.app.name
  port                     = 80
  protocol                 = "HTTP"

  connection_configuration {
    idle_timeout_in_seconds = 60
  }
}

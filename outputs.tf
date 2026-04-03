output "load_balancer_public_ip" {
  description = "Public IP of the Load Balancer — open this in your browser"
  value       = oci_load_balancer_load_balancer.main.ip_address_details[0].ip_address
}

output "vcn_id" {
  value = oci_core_vcn.main.id
}

output "mysql_endpoint" {
  description = "Internal MySQL hostname (accessible from app subnet only)"
  value       = oci_mysql_mysql_db_system.main.endpoints[0].hostname
  sensitive   = true
}

output "instance_pool_id" {
  value = oci_core_instance_pool.app.id
}

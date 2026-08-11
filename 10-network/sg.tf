resource "oci_core_security_list" "internal" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "internal-sl"

  ingress_security_rules {
    protocol = "all"
    source   = "10.0.0.0/16"
  }

  # Preserve the node-port health checks created for the current public load
  # balancer. These were present in OCI state but missing from the archive.
  ingress_security_rules {
    protocol = "6"
    source   = "10.0.0.0/24"

    tcp_options {
      min = 31598
      max = 31598
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "10.0.0.0/24"

    tcp_options {
      min = 32703
      max = 32703
    }
  }

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }
}

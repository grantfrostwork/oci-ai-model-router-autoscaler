# ---------- API endpoint ----------
resource "oci_core_network_security_group" "api" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "api-nsg"
}

# kubectl from your workstation only
resource "oci_core_network_security_group_security_rule" "api_from_me" {
  network_security_group_id = oci_core_network_security_group.api.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.my_ip_cidr

  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

# control plane <-> workers and pods
resource "oci_core_network_security_group_security_rule" "api_from_vcn" {
  network_security_group_id = oci_core_network_security_group.api.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = "10.0.0.0/16"
}

resource "oci_core_network_security_group_security_rule" "api_egress" {
  network_security_group_id = oci_core_network_security_group.api.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
}

# ---------- Workers ----------
resource "oci_core_network_security_group" "workers" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "workers-nsg"
}

resource "oci_core_network_security_group_security_rule" "workers_from_vcn" {
  network_security_group_id = oci_core_network_security_group.workers.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = "10.0.0.0/16"
}

resource "oci_core_network_security_group_security_rule" "workers_egress" {
  network_security_group_id = oci_core_network_security_group.workers.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
}

# ---------- Pods ----------
resource "oci_core_network_security_group" "pods" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "pods-nsg"
}

resource "oci_core_network_security_group_security_rule" "pods_from_vcn" {
  network_security_group_id = oci_core_network_security_group.pods.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = "10.0.0.0/16"
}

resource "oci_core_network_security_group_security_rule" "pods_egress" {
  network_security_group_id = oci_core_network_security_group.pods.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "0.0.0.0/0"
}

# ---------- Load balancers ----------
resource "oci_core_network_security_group" "lb" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "lb-nsg"
}

resource "oci_core_network_security_group_security_rule" "lb_https" {
  network_security_group_id = oci_core_network_security_group.lb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_http" {
  network_security_group_id = oci_core_network_security_group.lb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"

  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_egress" {
  network_security_group_id = oci_core_network_security_group.lb.id
  direction                 = "EGRESS"
  protocol                  = "all"
  destination               = "10.0.0.0/16"
}

# ---------- Outputs ----------
output "vcn_id" {
  value = oci_core_vcn.this.id
}

output "subnet_ids" {
  value = {
    lb      = oci_core_subnet.lb.id
    api     = oci_core_subnet.api.id
    workers = oci_core_subnet.workers.id
    pods    = oci_core_subnet.pods.id
  }
}

output "nsg_ids" {
  value = {
    lb      = oci_core_network_security_group.lb.id
    api     = oci_core_network_security_group.api.id
    workers = oci_core_network_security_group.workers.id
    pods    = oci_core_network_security_group.pods.id
  }
}

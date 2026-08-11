resource "oci_core_subnet" "lb" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = "10.0.0.0/24"
  display_name               = "lb"
  dns_label                  = "lb"
  route_table_id             = oci_core_route_table.public.id
  prohibit_public_ip_on_vnic = false
}

resource "oci_core_subnet" "api" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = "10.0.1.0/28"
  display_name               = "api"
  dns_label                  = "api"
  route_table_id             = oci_core_route_table.public.id
  prohibit_public_ip_on_vnic = false
}

resource "oci_core_subnet" "workers" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = "10.0.2.0/24"
  display_name               = "workers"
  dns_label                  = "workers"
  route_table_id             = oci_core_route_table.private.id
  prohibit_public_ip_on_vnic = true
  security_list_ids          = [oci_core_security_list.internal.id]
}


resource "oci_core_subnet" "pods" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = "10.0.16.0/22"
  display_name               = "pods"
  dns_label                  = "pods"
  route_table_id             = oci_core_route_table.private.id
  prohibit_public_ip_on_vnic = true
  security_list_ids          = [oci_core_security_list.internal.id]
}

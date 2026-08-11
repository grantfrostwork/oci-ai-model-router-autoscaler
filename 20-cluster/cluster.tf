resource "oci_containerengine_cluster" "this" {
  compartment_id     = var.compartment_ocid
  name               = "inference-poc"
  kubernetes_version = var.k8s_version
  vcn_id             = data.terraform_remote_state.network.outputs.vcn_id
  type               = "ENHANCED_CLUSTER"

  cluster_pod_network_options {
    cni_type = "OCI_VCN_IP_NATIVE"
  }

  endpoint_config {
    subnet_id            = local.subnets.api
    is_public_ip_enabled = true
    nsg_ids              = [local.nsgs.api]
  }

  options {
    service_lb_subnet_ids = [local.subnets.lb]

    kubernetes_network_config {
      services_cidr = "10.96.0.0/16"
    }

    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }
  }
}

output "cluster_id" { value = oci_containerengine_cluster.this.id }

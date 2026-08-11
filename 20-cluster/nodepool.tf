data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_containerengine_node_pool_option" "this" {
  node_pool_option_id = "all"
  compartment_id      = var.compartment_ocid
}

locals {
  oke_image_candidates = {
    for s in data.oci_containerengine_node_pool_option.this.sources :
    s.source_name => s.image_id
    if can(regex("Oracle-Linux-8", s.source_name))
    && can(regex(replace(var.k8s_version, "v", ""), s.source_name))
    && !can(regex("aarch64|GPU", s.source_name))
  }

  oke_image_name = reverse(sort(keys(local.oke_image_candidates)))[0]
  oke_image      = local.oke_image_candidates[local.oke_image_name]
}

output "selected_oke_image" {
  value = local.oke_image_name
}

resource "oci_containerengine_node_pool" "system" {
  cluster_id         = oci_containerengine_cluster.this.id
  compartment_id     = var.compartment_ocid
  name               = "system"
  kubernetes_version = var.k8s_version
  node_shape         = "VM.Standard.E5.Flex"
  ssh_public_key     = file(pathexpand(var.ssh_public_key_path))

  node_shape_config {
    ocpus         = 2
    memory_in_gbs = 16
  }

  node_source_details {
    source_type             = "IMAGE"
    image_id                = local.oke_image
    boot_volume_size_in_gbs = 100
  }

  node_config_details {
    size    = 2
    nsg_ids = [local.nsgs.workers]

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = local.subnets.workers
    }

    node_pool_pod_network_option_details {
      cni_type          = "OCI_VCN_IP_NATIVE"
      pod_subnet_ids    = [local.subnets.pods]
      max_pods_per_node = 31
      pod_nsg_ids       = [local.nsgs.pods]
    }
  }

  initial_node_labels {
    key   = "role"
    value = "system"
  }
}

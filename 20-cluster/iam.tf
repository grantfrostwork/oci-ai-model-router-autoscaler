locals {
  wi_condition = join(", ", [
    "request.principal.type = 'workload'",
    "request.principal.namespace = '${var.karpenter_namespace}'",
    "request.principal.service_account = '${var.karpenter_service_account}'",
    "request.principal.cluster_id = '${oci_containerengine_cluster.this.id}'",
  ])

  kpo_basic = [
    "manage instance-family",
    "manage volumes",
    "manage volume-attachments",
    "manage virtual-network-family",
    "inspect compartments",
  ]

  # Feature-specific. Keep tag-namespaces: you created a defined tag
  # namespace in Phase 0 and OCINodeClass will apply those tags.
  kpo_optional = [
    "use tag-namespaces",
  ]
}

resource "oci_identity_policy" "kpo_controller" {
  compartment_id = var.compartment_ocid
  name           = "kpo-controller"
  description    = "Karpenter Provider for OCI controller — workload identity"

  statements = [
    for verb_resource in concat(local.kpo_basic, local.kpo_optional) :
    "Allow any-user to ${verb_resource} in compartment ${var.compartment_name} where all {${local.wi_condition}}"
  ]
}

output "kpo_policy_id" { value = oci_identity_policy.kpo_controller.id }

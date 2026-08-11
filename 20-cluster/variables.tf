variable "tenancy_ocid" {
  type    = string
  default = "ocid1.tenancy.oc1..aaaaaaaa5trur7whdyytam4nmh3tinrx2yfqnbss6yzz4q6i7gmm2leagnkq"
}

variable "compartment_ocid" {
  type    = string
  default = "ocid1.compartment.oc1..aaaaaaaahalatvd7ffsoopo4rp5iqcefaqz7whc5umn5wrrnxe24rlbfm55a"
}

variable "compartment_name" {
  type    = string
  default = "Inference-project"
}

variable "region" {
  type    = string
  default = "us-ashburn-1"
}

variable "k8s_version" {
  type    = string
  default = "v1.34.1"
}

variable "karpenter_namespace" {
  type    = string
  default = "karpenter"
}

variable "karpenter_service_account" {
  type    = string
  default = "karpenter"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to the SSH public key installed on OKE managed worker nodes."
  default     = "~/.ssh/ssh-key-2023-11-16.key.pub"
}

variable "compartment_ocid" {
  type = string
}

variable "region" {
  type    = string
  default = "us-ashburn-1"
}

variable "k8s_version" {
  type = string
}

variable "my_ip_cidr" {
  type        = string
  description = "Public IPv4 CIDR allowed to reach the OKE API endpoint on TCP/6443. Prefer a single-address /32."

  validation {
    condition     = can(cidrnetmask(var.my_ip_cidr))
    error_message = "my_ip_cidr must be a valid IPv4 CIDR, for example 203.0.113.10/32."
  }
}

variable "name" {
  description = "EKS cluster name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,40}$", var.name))
    error_message = "name must be 3-40 lowercase letters, digits or hyphens."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes control plane version, e.g. \"1.34\"."
  type        = string
  default     = "1.34"

  validation {
    condition     = can(regex("^1\\.[0-9]{2}$", var.kubernetes_version))
    error_message = "kubernetes_version must look like 1.34."
  }
}

variable "subnet_ids" {
  description = "Private subnet IDs for the control plane ENIs and worker nodes (at least two AZs)."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "EKS requires subnets in at least two availability zones."
  }
}

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API publicly. Keep false for production and reach it over VPN or a bastion."
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint (only used when endpoint_public_access is true)."
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.public_access_cidrs, "0.0.0.0/0")
    error_message = "Refusing to open the Kubernetes API to 0.0.0.0/0; list your office or VPN ranges."
  }
}

variable "node_groups" {
  description = "Managed node groups keyed by name."
  type = map(object({
    instance_types = list(string)
    capacity_type  = optional(string, "ON_DEMAND")
    min_size       = number
    max_size       = number
    desired_size   = number
    disk_size_gb   = optional(number, 50)
    labels         = optional(map(string), {})
  }))

  validation {
    condition     = alltrue([for ng in values(var.node_groups) : contains(["ON_DEMAND", "SPOT"], ng.capacity_type)])
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }

  validation {
    condition     = alltrue([for ng in values(var.node_groups) : ng.min_size <= ng.desired_size && ng.desired_size <= ng.max_size])
    error_message = "Each node group needs min_size <= desired_size <= max_size."
  }
}

variable "cluster_log_types" {
  description = "Control plane log types sent to CloudWatch."
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "log_retention_days" {
  description = "Retention for the control plane log group."
  type        = number
  default     = 30
}

variable "log_kms_key_arn" {
  description = "Optional customer-managed KMS key for the control plane log group. The key policy must allow CloudWatch Logs."
  type        = string
  default     = null
}

variable "addons" {
  description = "EKS managed add-ons to install. Versions default to the one AWS marks as default for the cluster version."
  type        = list(string)
  default     = ["vpc-cni", "coredns", "kube-proxy", "eks-pod-identity-agent"]
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}

variable "name" {
  description = "Name prefix for all resources."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,32}$", var.name))
    error_message = "name must be 3-32 lowercase letters, digits or hyphens."
  }
}

variable "cidr" {
  description = "IPv4 CIDR block for the VPC, e.g. 10.0.0.0/16."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr, 0)) && tonumber(split("/", var.cidr)[1]) >= 16 && tonumber(split("/", var.cidr)[1]) <= 24
    error_message = "cidr must be a valid IPv4 CIDR between /16 and /24."
  }
}

variable "azs" {
  description = "Availability zones to spread subnets across. One public and one private subnet per AZ."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2 && length(var.azs) <= 4
    error_message = "Use between 2 and 4 availability zones; one AZ is not highly available."
  }
}

variable "subnet_newbits" {
  description = "Bits added to the VPC prefix for each subnet. 4 on a /16 gives /20 subnets (4091 usable IPs)."
  type        = number
  default     = 4
}

variable "nat_mode" {
  description = "NAT gateway layout: \"single\" (cheapest, one AZ is a SPOF), \"per_az\" (HA) or \"none\"."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["single", "per_az", "none"], var.nat_mode)
    error_message = "nat_mode must be one of: single, per_az, none."
  }
}

variable "enable_flow_logs" {
  description = "Send VPC flow logs to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Retention for the flow log group."
  type        = number
  default     = 30
}

variable "flow_log_kms_key_arn" {
  description = "Optional customer-managed KMS key for the flow log group. The key policy must allow CloudWatch Logs."
  type        = string
  default     = null
}

variable "eks_cluster_name" {
  description = "If set, subnets are tagged for EKS load balancer discovery for this cluster."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}

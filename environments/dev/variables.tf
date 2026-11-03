variable "region" {
  description = "AWS region."
  type        = string
  default     = "ap-south-1"
}

variable "api_allowed_cidrs" {
  description = "CIDRs allowed to reach the public Kubernetes API in dev (e.g. office or VPN egress)."
  type        = list(string)
  default     = ["203.0.113.0/24"] # TEST-NET-3 placeholder
}

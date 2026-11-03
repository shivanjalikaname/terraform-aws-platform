variable "role_name" {
  description = "Name of the IAM role GitHub Actions will assume."
  type        = string
}

variable "repositories" {
  description = "GitHub repositories allowed to assume the role, as owner/name."
  type        = list(string)

  validation {
    condition     = length(var.repositories) > 0 && alltrue([for r in var.repositories : can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", r))])
    error_message = "repositories must be a non-empty list of owner/name strings (no wildcards)."
  }
}

variable "allowed_refs" {
  description = "Git refs allowed to assume the role, e.g. refs/heads/main or refs/tags/v*."
  type        = list(string)
  default     = ["refs/heads/main"]
}

variable "allowed_environments" {
  description = "GitHub deployment environments allowed to assume the role (jobs using `environment:`)."
  type        = list(string)
  default     = []
}

variable "allow_pull_requests" {
  description = "Allow workflows triggered by pull_request. Only attach read-only policies (for plan) when enabling this."
  type        = bool
  default     = false
}

variable "policy_arns" {
  description = "Managed policy ARNs to attach to the role."
  type        = list(string)
  default     = []
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false if the account already has one."
  type        = bool
  default     = true
}

variable "max_session_duration" {
  description = "Maximum session length in seconds."
  type        = number
  default     = 3600
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}

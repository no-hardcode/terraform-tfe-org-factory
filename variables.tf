variable "organization_name" {
  type        = string
  description = "(Required) Name of organization to use for resource management."
}

variable "create_new_organization" {
  type        = bool
  description = "(Optional) Whether to create a new organization or use an existing one. Defaults to false."
  default     = false
}

variable "organization_email" {
  type        = string
  description = "(Optional) Email of owner for organization. **Required** when creating new organization."
  default     = ""
}

variable "teams_file_path" {
  description = "(Required) Path to JSON file holding teams configuration. See example JSON file in documentation for more information."
  type        = string
}

variable "workspaces_file_path" {
  description = "(Required) Path to JSON file holding workspaces configuration. See example JSON file in documentation for more information."
  type        = string
}
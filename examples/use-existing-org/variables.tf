variable "organization_name" {
  type        = string
  description = "(Required) Name of existing organization to manage."
}

variable "teams_file_path" {
  type        = string
  description = "(Optional) Path of JSON config file. Defaults to basic_config.json"
  default     = "basic_config.json"
}

variable "workspaces_file_path" {
  type        = string
  description = "(Optional) Path of JSON config file. Defaults to basic_config.json"
  default     = "basic_config.json"
}
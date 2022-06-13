# Configure existing organization with module
module "tfe_workspace" {
  source = "../.."

  organization_name = var.organization_name
  teams_file_path  = var.teams_file_path
  workspaces_file_path  = var.workspaces_file_path
}
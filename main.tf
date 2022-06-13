# Create an organization depending on var.create_new_organization
resource "tfe_organization" "org" {
  count = var.create_new_organization ? 1 : 0
  name  = var.organization_name
  email = var.organization_email
}

locals {

  # Set the organization name depending on whether its a new org or existing
  organization_name = var.create_new_organization ? tfe_organization.org[0].id : var.organization_name

  # Import org data from json file
  teams_data = jsondecode(file("${var.teams_file_path}"))
  workspaces_data = jsondecode(file("${var.workspaces_file_path}"))

  # Try to extract the workspace data
  raw_workspaces = try(local.workspaces_data.workspaces, [])

  # Normalize the workspace data, at the very least it needs to have a name
  workspaces = [for workspace in local.raw_workspaces : {
    name                  = workspace["name"]
    auto_apply            = try(workspace["auto_apply"], false)
    allow_destroy_plan    = try(workspace["allow_destroy_plan"], true)
    description           = try(workspace["description"], "No description provided.")
    execution_mode        = try(workspace["execution_mode"], "remote")
    file_triggers_enabled = try(workspace["file_triggers_enabled"], false)
    global_remote_state   = try(workspace["global_remote_state"], false)
    queue_all_runs        = try(workspace["queue_all_runs"], false)
    speculative_enabled   = try(workspace["speculative_enabled"], true)
    teams                 = try(workspace["teams"], [])
    terraform_version     = try(workspace["terraform_version"], "~> 1.0")
    tag_names             = try(workspace["tag_names"], [])
    vcs_repo              = try(workspace["vcs_repo"], {})
  }]

  #Create a list of workspace access entries
  workspace_team_access = flatten([
    for workspace in local.workspaces : [
      for team in workspace["teams"] : {
        workspace_name = workspace["name"]
        team_name      = team["name"]
        access_level   = team["access_level"]
      }
    ]
  ])

  # Try to extract the team data
  raw_teams = try(local.teams_data.teams, [])

  # Normalize the teams data, each team at least needs a name
  teams = [for team in local.raw_teams : {
    name                = team["name"]
    visibility          = try(team["visibility"], "secret")
    organization_access = try(team["organization_access"], {})
    members             = try(team["members"], [])
  }]

}

# Create workspaces
resource "tfe_workspace" "workspaces" {
  # Create a map of workspaces from the list stored in JSON using the
  # workspace name as the key
  for_each              = { for workspace in local.workspaces : workspace["name"] => workspace }
  name                  = each.key
  auto_apply            = each.value["auto_apply"]
  allow_destroy_plan    = each.value["allow_destroy_plan"]
  description           = each.value["description"]
  execution_mode        = each.value["execution_mode"]
  file_triggers_enabled = each.value["file_triggers_enabled"]
  global_remote_state   = each.value["global_remote_state"]
  queue_all_runs        = each.value["queue_all_runs"]
  organization          = local.organization_name
  speculative_enabled   = each.value["speculative_enabled"]
  terraform_version     = each.value["terraform_version"]
  tag_names             = each.value["tag_names"]

  # Create a single vcs_repo block if value isn't an empty map
  dynamic "vcs_repo" {
    for_each = each.value["vcs_repo"] != {} ? toset(["1"]) : toset([])

    content {
      branch             = try(each.value.vcs_repo["branch"], "main")
      identifier         = each.value.vcs_repo["identifier"]
      ingress_submodules = try(each.value.vcs_repo["ingress_submodules"], false)
      oauth_token_id     = each.value.vcs_repo["oauth_token_id"]
    }
  }
}

# Create teams
resource "tfe_team" "teams" {
  # Create a map of teams from the list stored in JSON using the 
  # team name as the key
  for_each     = { for team in local.teams : team["name"] => team }
  name         = each.key
  organization = local.organization_name
  visibility   = each.value["visibility"]

  # Create a single organization_access block if value isn't an empty map
  dynamic "organization_access" {
    for_each = each.value["organization_access"] != {} ? toset(["1"]) : toset([])

    content {
      # Get the value for each permission if it exists, set to false if it doesn't
      manage_policies         = try(each.value.organization_access["manage_policies"], false)
      manage_policy_overrides = try(each.value.organization_access["manage_policy_overrides"], false)
      manage_workspaces       = try(each.value.organization_access["manage_workspaces"], false)
      manage_vcs_settings     = try(each.value.organization_access["manage_vcs_settings"], false)
      manage_modules          = try(each.value.organization_access["manage_modules"], false)
      manage_providers        = try(each.value.organization_access["manage_providers"], false)
#wait for 0.32 release
#      manage_run_tasks        = try(each.value.organization_access["manage_run_tasks"], false)
    }
  }
}


# Configure workspace access for teams
resource "tfe_team_access" "team_access" {
  for_each     = { for access in local.workspace_team_access : "${access.workspace_name}_${access.team_name}" => access }
  access       = each.value["access_level"]
  team_id      = tfe_team.teams[each.value["team_name"]].id
  workspace_id = tfe_workspace.workspaces[each.value["workspace_name"]].id
}

# Add TFC accounts to the organization
resource "tfe_organization_membership" "org_members" {
  for_each     = toset(flatten(local.teams.*.members))
  organization = local.organization_name
  email        = each.value
}

locals {
  # Create a list of member mappings like this
  # team_name = team_name
  # member_name = member_email
  team_members = flatten([
    for team in local.teams : [
      for member in team["members"] : {
        team_name   = team["name"]
        member_name = member
      } if length(team["members"]) > 0
    ]
  ])
}

resource "tfe_team_organization_member" "team_members" {
  # Create a map with the team name and member name combines as a key for uniqueness
  for_each                   = { for member in local.team_members : "${member.team_name}_${member.member_name}" => member }
  team_id                    = tfe_team.teams[each.value["team_name"]].id
  organization_membership_id = tfe_organization_membership.org_members[each.value["member_name"]].id
}
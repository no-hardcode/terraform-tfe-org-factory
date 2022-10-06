terraform {

  required_version = ">= 1.1.0"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = ">= 0.37.0"
    }
  }
}

# Use the TFE_TOKEN environment variable for TFE authentication
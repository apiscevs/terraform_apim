terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # pick a version your environment supports
      version = ">= 4.0"
    }
    time = {
      source = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "azurerm" {
  features {}

  # Update with your own subscription
  subscription_id = "0be16117-cc59-4569-8479-007b4054638a"
}

#
# Call the "base" module (creates RG + APIM).
#
module "base" {
  source       = "./modules/base"

  rg_name      = "example-apim-rg"
  rg_location  = "westeurope"
  apim_name    = "apim-apiscevs-v2"
}

#
# Call the "child" module (creates an API in the APIM).
# We pass down the outputs from the base module.
#
module "child" {
  source    = "./modules/child"

  apim_id   = module.base.apim_id
  apim_name = module.base.apim_name
  rg_name   = module.base.rg_name
}

terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    time = {
      source = "hashicorp/time"
    }
  }
}

# 1) Wait 30s if the parent APIM is newly created or changed
resource "time_sleep" "wait_for_apim" {
  create_duration = "30s"

  # If the 'apim_id' changes, it triggers a re-create of this resource
  # which re-triggers the 30-second sleep. Otherwise, no extra wait.
  triggers = {
    apim_id = var.apim_id
  }
}

# 2) Now define an API that depends on the wait
resource "azurerm_api_management_api" "petstore_api" {
  depends_on         = [time_sleep.wait_for_apim]
  name               = "petstore-api-dev"
  resource_group_name   = var.rg_name
  api_management_name   = var.apim_name

  display_name          = "Petstore API dev"
  revision              = "1"
  path                  = "dev/petstore"
  protocols             = ["https"]
  subscription_required = false

  # Example swagger file in the same folder
  import {
    content_format = "swagger-json"
    content_value  = file("${path.module}/swagger.json")
  }
}

# 3) Now define an second API that depends on the wait
resource "azurerm_api_management_api" "petstore_api_2" {
  # depends_on         = [time_sleep.wait_for_apim, azurerm_api_management_api.petstore_api] # azurerm_api_management_api.petstore_api is a fix, create one by one
  depends_on         = [azurerm_api_management_api.petstore_api] # azurerm_api_management_api.petstore_api is a fix, create one by one
  name               = "petstore-api-dev-2"
  resource_group_name   = var.rg_name
  api_management_name   = var.apim_name

  display_name          = "Petstore API dev #2"
  revision              = "1"
  path                  = "dev/petstore-2"
  protocols             = ["https"]
  subscription_required = false

  # Example swagger file in the same folder
  import {
    content_format = "swagger-json"
    content_value  = file("${path.module}/swagger.json")
  }
}

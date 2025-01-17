terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.15.0"
    }
  }
}

provider "azurerm" {
  features {}
  
  subscription_id = "0be16117-cc59-4569-8479-007b4054638a"
}

# Resource Group
resource "azurerm_resource_group" "example" {
  name     = "example-apim-rg"
  location = "West Europe"
}

# API Management Service
resource "azurerm_api_management" "example" {
  name                = "example-apim"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  publisher_name      = "My Company"
  publisher_email     = "company@terraform.io"

  sku_name = "Developer_1" # Format: "SKUName_Capacity"
}

# Named Value
resource "azurerm_api_management_named_value" "example" {
  api_management_name = azurerm_api_management.example.name
  resource_group_name = azurerm_resource_group.example.name

  name          = "example-named-value"
  display_name  = "Example_Named_Value" # Replaced spaces with underscores
  value         = "dummy-secret-value"
  tags          = ["example", "demo"]
}

# Backend Configuration
resource "azurerm_api_management_backend" "example" {
  api_management_name = azurerm_api_management.example.name
  resource_group_name = azurerm_resource_group.example.name

  name         = "petstore-backend"
  description  = "Backend for Swagger Petstore API"
  url          = "https://petstore.swagger.io/v2"
  protocol     = "http" # Must be "http" or "soap"
  credentials {
    header = {
      Authorization = "Bearer some-token" # Use a map for headers
    }
  }
}

# API Definition
resource "azurerm_api_management_api" "example" {
  name                = "petstore-api"
  api_management_name = azurerm_api_management.example.name
  resource_group_name = azurerm_resource_group.example.name

  display_name = "Petstore API"
  revision     = "1" # Required
  path         = "petstore"
  protocols    = ["https"]

  import {
    content_format = "swagger-link-json"
    content_value  = "https://petstore.swagger.io/v2/swagger.json"
  }
}

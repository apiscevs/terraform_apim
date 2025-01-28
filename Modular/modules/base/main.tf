resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.rg_location
}

resource "azurerm_api_management" "apim" {
  name                = var.apim_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  publisher_name  = "My Company"
  publisher_email = "company@example.com"
  sku_name        = "Developer_1"
}

# ----------------------------------------------------------
# 4. Backend Configuration (example)
# ----------------------------------------------------------
resource "azurerm_api_management_backend" "apim_backend_dev1" {
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  name        = var.apim_atom_backend_dev1.name
  description = var.apim_atom_backend_dev1.description
  url         = var.apim_atom_backend_dev1.url
  protocol    = var.apim_atom_backend_dev1.protocol
}

# ----------------------------------------------------------
# 6. SFMP Product
# ----------------------------------------------------------
resource "azurerm_api_management_product" "sfmp_product_dev1" {
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  product_id            = var.sfmp_product_config_dev1.product_id
  display_name          = var.sfmp_product_config_dev1.display_name
  description           = var.sfmp_product_config_dev1.description
  terms                 = var.sfmp_product_config_dev1.terms
  subscription_required = var.sfmp_product_config_dev1.subscription_required
  approval_required     = var.sfmp_product_config_dev1.approval_required
  published             = var.sfmp_product_config_dev1.published
}

output "apim_details-output" {
  value = {
    apim_name  = azurerm_api_management.apim.name
    rg_name    = azurerm_resource_group.rg.name
  }
}
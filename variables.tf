variable "audience" {
  type = object({
    name     = string
    display_Name = string
    value = string
  })

  default = {
    name     = "atom_audience"
    display_Name = "atom_audience"
    value = "atom-local-http-access-token"
  }
}

variable "rg_apim" {
  type = object({
    name     = string
    location = string
  })

  default = {
    name     = "example-apim-rg"
    location = "West Europe"
  }
}

variable "apim_service" {
  type = object({
    name     = string
    publisher_name = string
    publisher_email = string
    sku_name = string
  })

  default = {
    name     = "apim-apiscevs-v2"
    publisher_name = "My Company"
    publisher_email = "company@terraform.io"
    sku_name = "Developer_1" # Format: "SKUName_Capacity"
  }
}

variable "apim_atom_backend_dev1" {
  type = object({
    name     = string
    description = string
    url = string
    protocol = string
  })

  default = {
    name     = "petstore-backend-dev1"
    description = "Backend for Swagger Petstore API"
    url = "https://petstore.swagger.io/v2"
    protocol = "http"
  }
}

variable "apim_atom_backend_dev2" {
  type = object({
    name     = string
    description = string
    url = string
    protocol = string
  })

  default = {
    name     = "petstore-backend-dev2"
    description = "Backend for Swagger Petstore API"
    url = "https://petstore.swagger.io/v2"
    protocol = "http"
  }
}

variable "petstore_api_config_dev1" {
  type = object({
    name            = string
    display_name    = string
    revision        = string
    path            = string
    content_format  = string
    swagger_file    = string
  })
  default = {
    name            = "petstore-api-dev1"
    display_name    = "Petstore API dev1"
    revision        = "1"
    path            = "dev1/petstore"
    content_format  = "swagger-json"
    swagger_file    = "APIM/OpenApi/swagger.json"  # Relative path without ${path.root}
  }
}

variable "petstore_api_config_dev2" {
  type = object({
    name            = string
    display_name    = string
    revision        = string
    path            = string
    content_format  = string
    swagger_file    = string
  })
  default = {
    name            = "petstore-api-dev2"
    display_name    = "Petstore API dev2"
    revision        = "1"
    path            = "dev2/petstore"
    content_format  = "swagger-json"
    swagger_file    = "APIM/OpenApi/swagger.json"  # Relative path without ${path.root}
  }
}

variable "sfmp_product_config_dev1" {
  type = object({
    product_id            = string
    display_name          = string
    description           = string
    terms                 = string
    subscription_required = bool
    approval_required     = bool
    published             = bool
  })

  default = {
    product_id            = "sfmp_dev1"
    display_name          = "SFMP Product dev1"
    description           = "This product contains APIs for SFMP dev1"
    terms                 = "By using this API, you agree to the terms and conditions. dev1"
    subscription_required = false
    approval_required     = false
    published             = true
  }
}

variable "sfmp_product_config_dev2" {
  type = object({
    product_id            = string
    display_name          = string
    description           = string
    terms                 = string
    subscription_required = bool
    approval_required     = bool
    published             = bool
  })

  default = {
    product_id            = "sfmp_dev2"
    display_name          = "SFMP Product dev2"
    description           = "This product contains APIs for SFMP dev2"
    terms                 = "By using this API, you agree to the terms and conditions. dev2"
    subscription_required = false
    approval_required     = false
    published             = true
  }
}
variable "rg_name" {
  type = string
}

variable "rg_location" {
  type = string
}

variable "apim_name" {
  type = string
}

variable "apim_atom_backend_dev1" {
  type = object({
    name     = string
    description = string
    url = string
    protocol = string
  })

  default = {
    name     = "backend-dev3"
    description = "Backend for Swagger Petstore API"
    url = "https://petstore.swagger.io/v2"
    protocol = "http"
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
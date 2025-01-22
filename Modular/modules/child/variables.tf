variable "apim_id" {
  type        = string
  description = "Parent APIM resource ID (used as a trigger)."
}

variable "apim_name" {
  type        = string
  description = "The APIM service name from the parent module."
}

variable "rg_name" {
  type        = string
  description = "Resource group name that APIM belongs to."
}

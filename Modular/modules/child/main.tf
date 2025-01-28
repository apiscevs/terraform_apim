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


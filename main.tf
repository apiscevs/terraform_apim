############################################################
# main.tf
############################################################

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

  # Update with your own subscription
  subscription_id = "0be16117-cc59-4569-8479-007b4054638a"
}

# This will go to logical environment
locals{
  petstore_api_policy_xml = <<POLICY_XML
  <policies>
      <inbound>
          <base />
          <!-- Simple CORS policy example -->
          <cors>
              <allowed-origins>
                  <origin>https://some-allowed-origin.com</origin>
              </allowed-origins>
              <allowed-methods>
                  <method>GET</method>
                  <method>POST</method>
                  <method>PUT</method>
                  <method>DELETE</method>
              </allowed-methods>
              <allowed-headers>
                  <header>*</header>
              </allowed-headers>
          </cors>
          <!-- Extract Bearer token from the Authorization header -->
          <set-variable name="token" value="@{
        if (!context.Request.Headers.ContainsKey("Authorization"))
        {
            return string.Empty;
        }
        var authArray = context.Request.Headers["Authorization"];
        if (authArray == null || authArray.Length == 0)
        {
            return string.Empty;
        }
  
        var authHeader = authArray[0];
        var bearerPlaceholder = &quot;Bearer &quot;;
        if (authHeader?.StartsWith(bearerPlaceholder) != true)
        {
            return string.Empty;
        }
        return authHeader.Substring(bearerPlaceholder.Length).Trim();
      }" />
          <!-- Decode JWT payload -->
          <set-variable name="jwtPayloadJson" value="@{
        var tokenParts = context.Variables.GetValueOrDefault<string>(&quot;token&quot;)?.Split('.');
        if (tokenParts == null || tokenParts.Length < 2)
        {
            return string.Empty;
        }
  
        // Extract the Base64Url-encoded payload
        var base64Url = tokenParts[1];
  
        // Replace base64url chars
        var base64 = base64Url.Replace('-', '+').Replace('_', '/');
  
        // Pad to multiple of 4
        switch (base64.Length % 4)
        {
            case 2: base64 += &quot;==&quot;; break;
            case 3: base64 += &quot;=&quot;; break;
        }
  
        var bytes = System.Convert.FromBase64String(base64);
        return System.Text.Encoding.UTF8.GetString(bytes);
      }" />
          <!-- Extract 'iss' (issuer) from the JWT payload -->
          <set-variable name="tokenIssuer" value="@{
        var jsonPayload = context.Variables.GetValueOrDefault<string>(&quot;jwtPayloadJson&quot;);
        if (string.IsNullOrEmpty(jsonPayload))
        {
            return string.Empty;
        }
  
        dynamic payloadObj = Newtonsoft.Json.JsonConvert.DeserializeObject(jsonPayload);
        return (string)payloadObj?.iss ?? string.Empty;
      }" />
          <!-- Rate limit by client IP: 5 calls per minute -->
          <rate-limit-by-key calls="5" renewal-period="60" counter-key="@(context.Request.IpAddress)" />
          <!-- Validate JWT if an issuer was found (optional) -->
          <validate-jwt header-name="Authorization" failed-validation-httpcode="401" require-expiration-time="true" require-scheme="Bearer" require-signed-tokens="true" clock-skew="5" output-token-variable-name="validatedToken">
              <openid-config url="@{
          var tokenIssuer = context.Variables.GetValueOrDefault<string>(&quot;tokenIssuer&quot;);
          return $&quot;{tokenIssuer}/.well-known/openid-configuration&quot;;
        }" />
              <audiences>
                  <audience>{{atom_audience}}</audience>
  <audience>{{atom_audience}}</audience>
  <audience>{{atom_audience}}</audience>
              </audiences>
          </validate-jwt>
          <!-- Validate request body JSON -->
          <validate-content unspecified-content-type-action="ignore" max-size="1048576" size-exceeded-action="prevent" errors-variable-name="name">
              <content type="application/json" validate-as="json" action="prevent" />
          </validate-content>
          <!-- Forward to the backend (defined above) -->
          <set-backend-service backend-id="__BACKEND_ID__" />
      </inbound>
      <backend>
          <!-- Optional: Retry on 502 or 500, 3 times with exponential backoff -->
          <retry condition="@((int)context.Response.StatusCode == 502 || context.Response.StatusCode == 500)" count="3" interval="@((int)Math.Pow(2, 3))">
              <forward-request timeout="30" />
          </retry>
      </backend>
      <outbound>
          <base />
      </outbound>
      <!-- Example: on-error policy (custom error handling) -->
      <on-error>
          <choose>
              <when condition="@((int)context.Response.StatusCode == 400)">
                  <set-status code="400" reason="Bad Request" />
                  <set-header name="Content-Type" exists-action="override">
                      <value>application/json</value>
                  </set-header>
                  <set-body>@{
            var bodyResponse = new {
              statusCode = context.Response.StatusCode.ToString(),
              message = "testing"
            };
            return Newtonsoft.Json.JsonConvert.SerializeObject(bodyResponse);
          }</set-body>
              </when>
              <otherwise />
          </choose>
      </on-error>
  </policies>
  POLICY_XML

  petstore_create_user_policy_xml = <<POLICY_XML
  <policies>
      <inbound>
          <base />
          <set-header name="apim-x-specific" exists-action="append">
              <value>specific</value>
          </set-header>
      </inbound>
      <backend>
          <base />
      </backend>
      <outbound>
          <base />
      </outbound>
  </policies>
  POLICY_XML
}

# ----------------------------------------------------------
# 1. Resource Group
# ----------------------------------------------------------
resource "azurerm_resource_group" "apim_resource_group" {
  name     = var.rg_apim.name
  location = var.rg_apim.location
}

# ----------------------------------------------------------
# 2. API Management Service
# ----------------------------------------------------------
resource "azurerm_api_management" "apim_service" {
  name                = var.apim_service.name
  location            = azurerm_resource_group.apim_resource_group.location
  resource_group_name = azurerm_resource_group.apim_resource_group.name
  publisher_name      = var.apim_service.publisher_name
  publisher_email     = var.apim_service.publisher_email

  sku_name = var.apim_service.sku_name
}

# ----------------------------------------------------------
# 3. Named Values
# ----------------------------------------------------------
resource "azurerm_api_management_named_value" "apim_audience" {
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name

  name         = var.audience.name
  display_name = var.audience.display_Name
  value        = var.audience.value
  tags         = ["security", "jwt"]
}

# this is logical environment specific

# ----------------------------------------------------------
# 4. Backend Configuration (example)
# ----------------------------------------------------------
resource "azurerm_api_management_backend" "apim_backend_dev1" {
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name

  name        = var.apim_atom_backend_dev1.name
  description = var.apim_atom_backend_dev1.description
  url         = var.apim_atom_backend_dev1.url
  protocol    = var.apim_atom_backend_dev1.protocol
}

resource "azurerm_api_management_backend" "apim_backend_dev2" {
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name

  name        = var.apim_atom_backend_dev2.name
  description = var.apim_atom_backend_dev2.description
  url         = var.apim_atom_backend_dev2.url
  protocol    = var.apim_atom_backend_dev2.protocol
}

# ----------------------------------------------------------
# 5. API Definition
#    Imports the Petstore Swagger JSON.
# ----------------------------------------------------------
resource "azurerm_api_management_api" "petstore_api_dev1" {
  name                = var.petstore_api_config_dev1.name
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name

  display_name = var.petstore_api_config_dev1.display_name
  revision     = var.petstore_api_config_dev1.revision
  path         = var.petstore_api_config_dev1.path
  protocols    = ["https"]
  subscription_required = false
  
  import {
    content_format = var.petstore_api_config_dev1.content_format
    content_value  = file("${path.root}/${var.petstore_api_config_dev1.swagger_file}")
  }
  
  depends_on = [azurerm_api_management.apim_service]
}

resource "azurerm_api_management_api" "petstore_api_dev2" {
  name                = var.petstore_api_config_dev2.name
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name

  display_name = var.petstore_api_config_dev2.display_name
  revision     = var.petstore_api_config_dev2.revision
  path         = var.petstore_api_config_dev2.path
  protocols    = ["https"]
  subscription_required = false
  
  import {
    content_format = var.petstore_api_config_dev2.content_format
    content_value  = file("${path.root}/${var.petstore_api_config_dev2.swagger_file}")
  }

  depends_on = [azurerm_api_management.apim_service]
}

# ----------------------------------------------------------
# 6. SFMP Product
# ----------------------------------------------------------
resource "azurerm_api_management_product" "sfmp_product_dev1" {
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name

  product_id            = var.sfmp_product_config_dev1.product_id
  display_name          = var.sfmp_product_config_dev1.display_name
  description           = var.sfmp_product_config_dev1.description
  terms                 = var.sfmp_product_config_dev1.terms
  subscription_required = var.sfmp_product_config_dev1.subscription_required
  approval_required     = var.sfmp_product_config_dev1.approval_required
  published             = var.sfmp_product_config_dev1.published

  depends_on = [azurerm_api_management.apim_service]
}

resource "azurerm_api_management_product" "sfmp_product_dev2" {
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name

  product_id            = var.sfmp_product_config_dev2.product_id
  display_name          = var.sfmp_product_config_dev2.display_name
  description           = var.sfmp_product_config_dev2.description
  terms                 = var.sfmp_product_config_dev2.terms
  subscription_required = var.sfmp_product_config_dev2.subscription_required
  approval_required     = var.sfmp_product_config_dev2.approval_required
  published             = var.sfmp_product_config_dev2.published

  depends_on = [azurerm_api_management.apim_service]
}

# ----------------------------------------------------------
# 7. Associate Petstore API with SFMP Product
# ----------------------------------------------------------
resource "azurerm_api_management_product_api" "sfmp_product_api_dev1" {
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name

  product_id = azurerm_api_management_product.sfmp_product_dev1.product_id
  api_name   = azurerm_api_management_api.petstore_api_dev1.name

  depends_on = [azurerm_api_management_product.sfmp_product_dev1, azurerm_api_management_api.petstore_api_dev1]
}

resource "azurerm_api_management_product_api" "sfmp_product_api_dev2" {
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name

  product_id = azurerm_api_management_product.sfmp_product_dev2.product_id
  api_name   = azurerm_api_management_api.petstore_api_dev2.name

  depends_on = [azurerm_api_management_product.sfmp_product_dev2, azurerm_api_management_api.petstore_api_dev2]
}

# ----------------------------------------------------------
# 8. Apply a Policy to the Petstore API (all operations)
# ----------------------------------------------------------
resource "azurerm_api_management_api_policy" "petstore_api_policy_dev1" {
  resource_group_name = azurerm_resource_group.apim_resource_group.name
  api_management_name = azurerm_api_management.apim_service.name
  api_name            = azurerm_api_management_api.petstore_api_dev1.name

  depends_on = [
    azurerm_api_management_api.petstore_api_dev1, 
    azurerm_api_management_backend.apim_backend_dev1,
    azurerm_api_management_named_value.apim_audience]
  
  xml_content = replace(local.petstore_api_policy_xml, "__BACKEND_ID__", "petstore-backend-dev1")
}

resource "azurerm_api_management_api_policy" "petstore_api_policy_dev2" {
  resource_group_name = azurerm_resource_group.apim_resource_group.name
  api_management_name = azurerm_api_management.apim_service.name
  api_name            = azurerm_api_management_api.petstore_api_dev2.name

  depends_on = [
    azurerm_api_management_api.petstore_api_dev2, 
    azurerm_api_management_backend.apim_backend_dev2,
    azurerm_api_management_named_value.apim_audience]

  xml_content = replace(local.petstore_api_policy_xml, "__BACKEND_ID__", "petstore-backend-dev2")
}

# ----------------------------------------------------------
# 8. Example of specific policy for create-user operation 
# ----------------------------------------------------------
resource "azurerm_api_management_api_operation_policy" "create_user_policy_dev1" {
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name
  api_name            = azurerm_api_management_api.petstore_api_dev1.name
  operation_id        = "addPet"

  depends_on = [azurerm_api_management_api.petstore_api_dev1]
  
  xml_content = local.petstore_create_user_policy_xml
}

resource "azurerm_api_management_api_operation_policy" "create_user_policy_dev2" {
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name
  api_name            = azurerm_api_management_api.petstore_api_dev2.name
  operation_id        = "addPet"

  depends_on = [azurerm_api_management_api.petstore_api_dev2]
  
  xml_content = local.petstore_create_user_policy_xml
}


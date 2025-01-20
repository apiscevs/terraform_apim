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

# ----------------------------------------------------------
# 1. Resource Group
# ----------------------------------------------------------
resource "azurerm_resource_group" "apim_resource_group" {
  name     = "example-apim-rg"
  location = "West Europe"
}

# ----------------------------------------------------------
# 2. API Management Service
# ----------------------------------------------------------
resource "azurerm_api_management" "apim_service" {
  name                = "apim-apiscevs-v2"
  location            = azurerm_resource_group.apim_resource_group.location
  resource_group_name = azurerm_resource_group.apim_resource_group.name
  publisher_name      = "My Company"
  publisher_email     = "company@terraform.io"

  sku_name = "Developer_1" # Format: "SKUName_Capacity"
}

# ----------------------------------------------------------
# 3. Named Values
# ----------------------------------------------------------
resource "azurerm_api_management_named_value" "apim_named_value" {
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name

  name         = "example-named-value"
  display_name = "Example_Named_Value"
  value        = "dummy-secret-value"
  tags         = ["example", "demo"]
}

resource "azurerm_api_management_named_value" "apim_audience" {
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name

  name         = "atom_audience"
  display_name = "atom_audience"
  value        = "atom-local-http-access-token"
  tags         = ["security", "jwt"]
}

# ----------------------------------------------------------
# 4. Backend Configuration (example)
# ----------------------------------------------------------
resource "azurerm_api_management_backend" "apim_backend" {
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name

  name        = "petstore-backend"
  description = "Backend for Swagger Petstore API"
  url         = "https://petstore.swagger.io/v2"
  protocol    = "http"

  credentials {
    header = {
      Authorization = "Bearer some-token" # Use a map for headers
    }
  }
}

# ----------------------------------------------------------
# 5. API Definition
#    Imports the Petstore Swagger JSON.
# ----------------------------------------------------------
resource "azurerm_api_management_api" "petstore_api" {
  name                = "petstore-api"
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name

  display_name = "Petstore API"
  revision     = "1"
  path         = "petstore"
  protocols    = ["https"]

  import {
    content_format = "swagger-json"
    content_value  = file("${path.root}/APIM/OpenApi/swagger.json")
  }
}


# ----------------------------------------------------------
# 6. SFMP Product
# ----------------------------------------------------------
resource "azurerm_api_management_product" "sfmp_product" {
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name

  product_id   = "sfmp"
  display_name = "SFMP Product"
  description  = "This product contains APIs for SFMP"
  terms        = "By using this API, you agree to the terms and conditions."
  subscription_required = false
  approval_required     = false
  published             = true

  depends_on = [azurerm_api_management.apim_service]
}

# ----------------------------------------------------------
# 7. Associate Petstore API with SFMP Product
# ----------------------------------------------------------
resource "azurerm_api_management_product_api" "sfmp_product_api" {
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name

  product_id = azurerm_api_management_product.sfmp_product.product_id
  api_name   = azurerm_api_management_api.petstore_api.name

  depends_on = [azurerm_api_management_product.sfmp_product, azurerm_api_management_api.petstore_api]
}

# ----------------------------------------------------------
# 8. Apply a Policy to the Petstore API (all operations)
# ----------------------------------------------------------
resource "azurerm_api_management_api_policy" "petstore_api_policy" {
  resource_group_name = azurerm_resource_group.apim_resource_group.name
  api_management_name = azurerm_api_management.apim_service.name
  api_name            = azurerm_api_management_api.petstore_api.name

  depends_on = [azurerm_api_management_api.petstore_api]
  
  xml_content = <<POLICY_XML
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
        <set-backend-service backend-id="petstore-backend" />
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
}

# ----------------------------------------------------------
# 8. Example of specific policy for create-user operation 
# ----------------------------------------------------------
resource "azurerm_api_management_api_operation_policy" "create_user_policy" {
  api_management_name = azurerm_api_management.apim_service.name
  resource_group_name = azurerm_resource_group.apim_resource_group.name
  api_name            = azurerm_api_management_api.petstore_api.name
  operation_id        = "addPet"

  xml_content = <<POLICY_XML
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
param (
    [Parameter(Mandatory = $true)]
    [string]$EnvironmentName,

    [Parameter(Mandatory = $false)]
    [string]$ClientId,

    [Parameter(Mandatory = $false)]
    [string]$ClientSecret,

    [Parameter(Mandatory = $true)]
    [string]$ApiRevision
)

# Define the base configuration folder
$BaseConfigFolder = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -ChildPath "Configuration"

# Define the specific environment file path
$ConfigFilePath = Join-Path -Path $BaseConfigFolder -ChildPath "Environments\$EnvironmentName.json"

# Define shared paths for policy and swagger files
$PolicyFilePath = Join-Path -Path $BaseConfigFolder -ChildPath "Shared\Policies\api-shared-policy.xml"
$SwaggerFilePath = Join-Path -Path $BaseConfigFolder -ChildPath "Shared\Swagger\swagger.json"

# Check if the configuration file exists
if (-not (Test-Path $ConfigFilePath)) {
    Write-Error "Configuration file not found at path: $ConfigFilePath"
    exit 1
}

# Load configuration from the JSON file
try {
    $EnvConfig = Get-Content -Path $ConfigFilePath | ConvertFrom-Json
    $ResourceGroupName = $EnvConfig.ResourceGroupName
    $ApimName = $EnvConfig.ApimName
    $TenantId = $EnvConfig.TenantId
    $SubscriptionId = $EnvConfig.SubscriptionId
    $BackendId = $EnvConfig.BackendId
    $ProductId = $EnvConfig.ProductId

    # Ensure CORS origins is an array before transforming to XML format
    $CorsOrigins = (@($EnvConfig.CorsOrigins) | ForEach-Object { "<origin>$_</origin>" }) -join "`n        "
}
catch {
    Write-Error "Failed to load or parse configuration file: $ConfigFilePath. $_"
    exit 1
}

# Check if the policy and swagger files exist
if (-not (Test-Path $PolicyFilePath)) {
    Write-Error "Policy file not found at path: $PolicyFilePath"
    exit 1
}

if (-not (Test-Path $SwaggerFilePath)) {
    Write-Error "Swagger file not found at path: $SwaggerFilePath"
    exit 1
}

# Load configuration from the JSON file
try {
    $EnvConfig = Get-Content -Path $ConfigFilePath | ConvertFrom-Json
    $ResourceGroupName = $EnvConfig.ResourceGroupName
    $ApimName = $EnvConfig.ApimName
    $TenantId = $EnvConfig.TenantId
    $SubscriptionId = $EnvConfig.SubscriptionId
    $BackendId = $EnvConfig.BackendId
    $ProductId = $EnvConfig.ProductId 
    
    # Ensure CORS origins is an array before transforming to XML format
    $CorsOrigins = (@($EnvConfig.CorsOrigins) | ForEach-Object { "<origin>$_</origin>" }) -join "`n        "
}
catch {
    Write-Error "Failed to load or parse configuration file: $ConfigFilePath. $_"
    exit 1
}

# Check if the policy and swagger files exist
if (-not (Test-Path $PolicyFilePath)) {
    Write-Error "Policy file not found at path: $PolicyFilePath"
    exit 1
}

if (-not (Test-Path $SwaggerFilePath)) {
    Write-Error "Swagger file not found at path: $SwaggerFilePath"
    exit 1
}

Write-Host "Loaded configuration for environment: $EnvironmentName"
Write-Host "ResourceGroupName: $ResourceGroupName"
Write-Host "APIM Name: $ApimName"
Write-Host "Swagger File Path: $SwaggerFilePath"
Write-Host "Policy File Path: $PolicyFilePath"
Write-Host "Backend ID: $BackendId"

# Authenticate using the provided service principal credentials
Write-Host "Authenticating to Azure..."
try {
    if ($ClientId -and $ClientSecret) {
        # Service principal authentication
        Write-Host "Service principal credentials detected. Authenticating using ClientId and ClientSecret..."
        $SecurePassword = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $SecurePassword

        Connect-AzAccount -ServicePrincipal -TenantId $TenantId -Credential $Credential
        Write-Host "Authenticated successfully using service principal."
    } else {
        # Default account authentication with caching
        Write-Host "No service principal credentials detected. Using cached context or default Connect-AzAccount..."
        $context = Get-AzContext -ErrorAction SilentlyContinue
        if (-not $context) {
            Write-Host "No cached context found. Logging in interactively..."
            Connect-AzAccount -Subscription $SubscriptionId -Persist
        } else {
            Write-Host "Using cached context for authentication."
            Set-AzContext -Context $context
        }
        Write-Host "Authenticated successfully using the default admin account."
    }
}
catch {
    Write-Error "Failed to authenticate to Azure. $_"
    exit 1
}

# Read and replace placeholders in-memory without saving to files
try {
    $PolicyContent = Get-Content -Path $PolicyFilePath -Raw
    $UpdatedPolicyContent = $PolicyContent `
        -replace "__CORS_ORIGINS__", $CorsOrigins `
        -replace "__BACKEND_ID__", $BackendId

    # Debug: Print final policy content before applying
    Write-Host "Final Policy Content Being Applied:"
    Write-Host $UpdatedPolicyContent
}
catch {
    Write-Error "Failed to process policy file. $_"
    exit 1
}

Write-Host "Setting the current subscription to $SubscriptionId ..."
Set-AzContext -Subscription $SubscriptionId

# Verify APIM instance
Write-Host "Checking if APIM instance '$ApimName' in resource group '$ResourceGroupName' exists..."
try {
    $apimContext = New-AzApiManagementContext -ResourceGroupName $ResourceGroupName -ServiceName $ApimName
    Write-Host "APIM instance '$ApimName' found."
}
catch {
    Write-Error "API Management instance '$ApimName' not found in '$ResourceGroupName'. Exiting."
    exit 1
}

# Base API ID
$baseApiId = "my-api"

# Check for existing API revisions
try {
    $existingRevisions = Get-AzApiManagementApiRevision -Context $apimContext -ApiId $baseApiId
}
catch {
    $existingRevisions = @() # No revisions exist
}

# Handle different cases
if (-not $existingRevisions) {
    # Case 1: API does not exist, create the base API
    Write-Host "No API exists. Creating the base API and marking it as current..."
    try {
        Import-AzApiManagementApi `
            -Context $apimContext `
            -SpecificationPath $SwaggerFilePath `
            -SpecificationFormat "OpenApi" `
            -ApiId $baseApiId `
            -Path "my-api" `
            -Protocol "Https"     
        Write-Host "Base API created and set as current."
    }
    catch {
        Write-Error "Failed to create base API. $_"
        exit 1
    }
    
    Write-Host "🔧 Disabling subscription requirement for API '$baseApiId' using Azure REST API workaround..."
    # Existing bug was as usually closed with provided workaround that did not actually work for me.
    # https://github.com/Azure/azure-powershell/issues/9350   
    # Switched to RESET API approach    
    try {
        # Step 1: Get authentication token (Use -AsSecureString for future compatibility)
        $secureToken = (Get-AzAccessToken -ResourceUrl "https://management.azure.com" -AsSecureString).Token
    
        # Step 2: Convert SecureString to plain text
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        $token = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    
        # Step 3: Build REST API request URL
        $apiUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ApiManagement/service/$ApimName/apis/$baseApiId" + "?api-version=2021-08-01"
    
        # Debugging: Print the API URL to verify
        Write-Host "API Request URL: $apiUrl"
    
        # Step 4: Define the request body to update SubscriptionRequired to false
        $body = @{
            properties = @{
                subscriptionRequired = $false
            }
        } | ConvertTo-Json -Depth 3
    
        # Step 5: Send the PATCH request to update the API
        $headers = @{
            "Authorization" = "Bearer $token"
            "Content-Type"  = "application/json"
        }
    
        $response = Invoke-RestMethod -Uri $apiUrl -Method Patch -Headers $headers -Body $body -Verbose
    
        Write-Host "Subscription requirement disabled successfully for API '$baseApiId'."
    }
    catch {
        Write-Error "Failed to disable subscription requirement using REST API. $_"
        exit 1
    }
}
else {
    # Case 2: Handle existing revisions
    $existingRevision = $existingRevisions | Where-Object { $_.ApiRevision -eq $ApiRevision }

    if ($existingRevision) {
        # Revision exists
        if ($existingRevision.IsCurrent -eq $true) {
            Write-Host "Revision '$ApiRevision' is already current. No action needed."
        } else {
            Write-Host "Marking aged revision '$ApiRevision' as current with a unique release ID..."
            
            try {
                $releaseId = "my-api-release-$ApiRevision-$(Get-Date -Format 'yyyyMMddHHmmss')"

                Write-Host "Creating a new release '$releaseId' for aged revision '$ApiRevision'..."
                New-AzApiManagementApiRelease `
                    -Context $apimContext `
                    -ApiId $baseApiId `
                    -ReleaseId $releaseId `
                    -ApiRevision $ApiRevision
                Write-Host "Aged revision '$ApiRevision' successfully marked as current via release '$releaseId'."
            }
            catch {
                Write-Error "Failed to mark aged revision '$ApiRevision' as current via release. $_"
                exit 1
            }
        }
    }
    else {
        # Case 3: Create a new revision and make it current
        Write-Host "Revision '$ApiRevision' does not exist. Creating a new revision and marking it as current..."
        try {
            New-AzApiManagementApiRevision `
                -Context $apimContext `
                -ApiId $baseApiId `
                -ApiRevision $ApiRevision `
                -ApiRevisionDescription "Created by script."
            Write-Host "Revision '$ApiRevision' created successfully."

            $releaseId = "my-api-release-$ApiRevision"

            Write-Host "Creating a new release '$releaseId' for new revision '$ApiRevision'..."
            New-AzApiManagementApiRelease `
                -Context $apimContext `
                -ApiId $baseApiId `
                -ReleaseId $releaseId `
                -ApiRevision $ApiRevision `
                -Note "test from powershell"
                
            Write-Host "New revision '$ApiRevision' created and marked as current via release '$releaseId'."
        }
        catch {
            Write-Error "Failed to create or mark new revision '$ApiRevision' as current. $_"
            exit 1
        }
    }
}

# Update Swagger file for the current revision
Write-Host "Updating the API with Swagger file: $SwaggerFilePath ..."
try {
    Import-AzApiManagementApi `
        -Context $apimContext `
        -SpecificationPath $SwaggerFilePath `
        -SpecificationFormat "OpenApi" `
        -ApiId $baseApiId `
        -ApiRevision $ApiRevision `
        -Path "my-api" `
        -Protocol "Https"
    Write-Host "API updated with Swagger file."
}
catch {
    Write-Error "Failed to update API with Swagger file. $_"
    exit 1
}

# Apply the modified policy **directly** without saving to file
Write-Host "Applying updated policy..."
try {
    Set-AzApiManagementPolicy `
        -Context $apimContext `
        -ApiId $baseApiId `
        -Policy $UpdatedPolicyContent
    Write-Host "Policy set successfully."
}
catch {
    Write-Error "Failed to apply policy. $_"
    exit 1
}

# Associate API with a Product
if ($EnvConfig.ProductId) {
    Write-Host "Checking if API '$baseApiId' is already associated with product '$($EnvConfig.ProductId)'..."

    try {
        # Get all APIs in the APIM instance
        $allApis = Get-AzApiManagementApi -Context $apimContext

        # Check if our API exists in the list
        $apiExists = $allApis | Where-Object { $_.ApiId -eq $baseApiId }

        if (-not $apiExists) {
            Write-Error "API '$baseApiId' does not exist in APIM. Cannot associate with product '$($EnvConfig.ProductId)'."
            exit 1
        }

        # Check if our API is already associated with the product
        $productApis = Get-AzApiManagementProduct -Context $apimContext -ProductId $EnvConfig.ProductId
        $isApiLinked = $productApis | Where-Object { $_.ApiId -eq $baseApiId }

        if ($isApiLinked) {
            Write-Host "API '$baseApiId' is already associated with product '$($EnvConfig.ProductId)'. Skipping association."
        } else {
            Write-Host "🔗 Associating API '$baseApiId' with product '$($EnvConfig.ProductId)'..."
            Add-AzApiManagementApiToProduct `
                -Context $apimContext `
                -ProductId $EnvConfig.ProductId `
                -ApiId $baseApiId
            Write-Host "API successfully associated with product '$($EnvConfig.ProductId)'."
        }
    }
    catch {
        Write-Error "Failed to associate API with product. $_"
        exit 1
    }
} else {
    Write-Host "No ProductId found in configuration. Skipping API-product association."
}

Write-Host "`nDeployment finished successfully!"

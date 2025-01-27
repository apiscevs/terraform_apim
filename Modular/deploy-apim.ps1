param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$ApimName,

    [Parameter(Mandatory = $true)]
    [string]$SwaggerFilePath,

    [Parameter(Mandatory = $true)]
    [string]$PolicyFilePath,

    [Parameter(Mandatory = $true)]
    [string]$ClientId,

    [Parameter(Mandatory = $true)]
    [string]$ClientSecret,

    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$ApiRevision
)

Write-Host "Authenticating to Azure with service principal credentials..."

# 1) Login via service principal
try {
    $secureClientSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
    $psCred = New-Object System.Management.Automation.PSCredential($ClientId, $secureClientSecret)
    Connect-AzAccount -ServicePrincipal -Tenant $TenantId -Credential $psCred
}
catch {
    Write-Error "Failed to authenticate to Azure. $_"
    exit 1
}

Write-Host "Setting the current subscription to $SubscriptionId ..."
Set-AzContext -Subscription $SubscriptionId

Write-Host "Checking if APIM instance '$ApimName' in resource group '$ResourceGroupName' exists..."
try {
    $apimCheck = Get-AzApiManagement -ResourceGroupName $ResourceGroupName -Name $ApimName -ErrorAction Stop
    Write-Host "APIM instance '$ApimName' found."
}
catch {
    Write-Error "API Management instance '$ApimName' not found in '$ResourceGroupName'. Exiting."
    exit 1
}

Write-Host "Creating API Management context..."
try {
    $apimContext = New-AzApiManagementContext -ResourceGroupName $ResourceGroupName -ServiceName $ApimName
}
catch {
    Write-Error "Failed to create APIM context. $_"
    exit 1
}

# ------------------------------------------------------------------
# 2) Detect or create the specified API revision (if provided)
# ------------------------------------------------------------------

# Base API ID (without revision)
$baseApiId = "my-api"

if ($ApiRevision) {
    Write-Host "API revision parameter specified: $ApiRevision"
    # Check if that revision already exists
    try {
        $existingRevisions = Get-AzApiManagementApiRevision -Context $apimContext -ApiId $baseApiId
        $revisionMatch = $existingRevisions | Where-Object { $_.ApiRevision -eq $ApiRevision }
    }
    catch {
        # If the base API doesn't have any revisions yet, you'll get an empty result
        $revisionMatch = $null
    }

    if ($revisionMatch) {
        Write-Host "Revision '$ApiRevision' already exists. It will be updated."
    }
    else {
        Write-Host "Revision '$ApiRevision' does not exist. Creating a new revision..."
        try {
            New-AzApiManagementApiRevision `
                -Context $apimContext `
                -ApiId $baseApiId `
                -ApiRevision $ApiRevision `
                -ApiRevisionDescription "Created by script."
        }
        catch {
            Write-Error "Failed to create new revision '$ApiRevision': $_"
            exit 1
        }
    }

    # We'll import/update the specified revision
    # The final "API ID" effectively becomes "my-api;rev=<ApiRevision>" inside APIM
    $usedApiId = $baseApiId
    $usedApiRevision = $ApiRevision
}
else {
    Write-Host "No API revision specified. Using default (no revision)."
    $usedApiId = $baseApiId
    $usedApiRevision = $null
}

# ------------------------------------------------------------------
# 3) Import (or update) the Swagger file into the chosen revision
# ------------------------------------------------------------------
Write-Host "Importing (or updating) API from Swagger file: $SwaggerFilePath"

try {
    if ($usedApiRevision) {
        Import-AzApiManagementApi `
            -Context $apimContext `
            -SpecificationPath $SwaggerFilePath `
            -SpecificationFormat "OpenApi" `
            -ApiId $usedApiId `
            -ApiRevision $usedApiRevision `
            -Path "my-api" `
            -Protocol "Https"
    }
    else {
        # The original approach (no revision)
        Import-AzApiManagementApi `
            -Context $apimContext `
            -SpecificationPath $SwaggerFilePath `
            -SpecificationFormat "OpenApi" `
            -ApiId $usedApiId `
            -Path "my-api" `
            -Protocol "Https"
    }

    Write-Host "API import/update successful."
}
catch {
    Write-Error "Failed to import/update API: $_"
    exit 1
}

# ------------------------------------------------------------------
# 4) Update the display name
# ------------------------------------------------------------------
Write-Host "Updating the API display name to 'My API'..."
try {
    if ($usedApiRevision) {
        Update-AzApiManagementApi `
            -Context $apimContext `
            -ApiId $usedApiId `
            -ApiRevision $usedApiRevision `
            -DisplayName "My API"
    }
    else {
        Update-AzApiManagementApi `
            -Context $apimContext `
            -ApiId $usedApiId `
            -DisplayName "My API"
    }
    Write-Host "API display name updated."
}
catch {
    Write-Host "Warning: Could not update display name. $_"
}

# ------------------------------------------------------------------
# 5) Apply policy on the chosen revision
# ------------------------------------------------------------------
Write-Host "Applying policy from file: $PolicyFilePath ..."
try {
    if ($usedApiRevision) {
        Set-AzApiManagementPolicy `
            -Context $apimContext `
            -ApiId $usedApiId `
            -ApiRevision $usedApiRevision `
            -PolicyFilePath $PolicyFilePath
    }
    else {
        Set-AzApiManagementPolicy `
            -Context $apimContext `
            -ApiId $usedApiId `
            -PolicyFilePath $PolicyFilePath
    }
    Write-Host "Policy set successfully."
}
catch {
    Write-Error "Failed to set the API-scope policy: $_"
    exit 1
}

# ------------------------------------------------------------------
# 6) Make the revision current (if specified)
# ------------------------------------------------------------------
if ($usedApiRevision) {
    Write-Host "Marking revision '$usedApiRevision' as current..."
    try {
        Update-AzApiManagementApi `
            -Context $apimContext `
            -ApiId $usedApiId `
            -ApiRevision $usedApiRevision `
            -IsCurrent $true
        Write-Host "Revision '$usedApiRevision' is now current."
    }
    catch {
        Write-Host "Warning: Could not set revision '$usedApiRevision' as current. $_"
    }
}

Write-Host "`nDeployment finished successfully!"

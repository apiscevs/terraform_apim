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
    [string]$SubscriptionId
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

# 2) Import or Update the API
Write-Host "Importing (or updating) API from Swagger file: $SwaggerFilePath"
try {
    Import-AzApiManagementApi `
        -Context $apimContext `
        -SpecificationPath $SwaggerFilePath `
        -SpecificationFormat "OpenApi" `
        -ApiId "my-api" `
        -Path "my-api" `
        -Protocol "Https" `

    Write-Host "API import/update successful."
}
catch {
    Write-Error "Failed to import/update API: $_"
    exit 1
}

# 3) Set custom display name if desired
Write-Host "Updating the API display name to 'My API'..."
try {
    Update-AzApiManagementApi `
        -Context $apimContext `
        -ApiId "my-api" `
        -DisplayName "My API"
    Write-Host "API display name updated."
}
catch {
    Write-Host "Warning: Could not update display name. Possibly the API was imported with a display name from the Swagger spec."
}

# 4) Set policy on the API
Write-Host "Applying policy from file: $PolicyFilePath ..."
try {
    Set-AzApiManagementPolicy `
        -Context $apimContext `
        -ApiId "my-api" `
        -PolicyFilePath $PolicyFilePath
    Write-Host "Policy set successfully."
}
catch {
    Write-Error "Failed to set the API-scope policy: $_"
    exit 1
}

Write-Host "Deployment finished successfully!"

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

    [Parameter(Mandatory = $true)]
    [string]$ApiRevision
)

Write-Host "Authenticating to Azure with service principal credentials..."

# Authenticate to Azure
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
}
else {
    # Case 2: Handle existing revisions
    $existingRevision = $existingRevisions | Where-Object { $_.ApiRevision -eq $ApiRevision }

    if ($existingRevision) {
        # Revision exists
        if ($existingRevision.IsCurrent -eq $true) {
            Write-Host "Revision '$ApiRevision' is already current. No action needed."
        } else {
            Write-Host "Marking revision '$ApiRevision' as current using a unique release ID..."
            
            try {
                # Define a unique release ID using the current timestamp
                $releaseId = "my-api-release-$(Get-Date -Format 'yyyyMMddHHmmss')"

                # Create a new release pointing to the desired revision
                Write-Host "Creating a new release '$releaseId' for revision '$ApiRevision'..."
                New-AzApiManagementApiRelease `
                    -Context $apimContext `
                    -ApiId $baseApiId `
                    -ReleaseId $releaseId `
                    -ApiRevision $ApiRevision
                Write-Host "Revision '$ApiRevision' successfully marked as current via release '$releaseId'."
            }
            catch {
                Write-Error "Failed to mark revision '$ApiRevision' as current via release. $_"
                exit 1
            }
        }
    }
    else {
        # Case 3: Create a new revision and make it current
        Write-Host "Revision '$ApiRevision' does not exist. Creating a new revision and marking it as current..."
        try {
            # Create the new revision
            New-AzApiManagementApiRevision `
                -Context $apimContext `
                -ApiId $baseApiId `
                -ApiRevision $ApiRevision `
                -ApiRevisionDescription "Created by script."
            Write-Host "Revision '$ApiRevision' created successfully."

            # Define a unique release ID for the new revision
            $releaseId = "my-api-release-$(Get-Date -Format 'yyyyMMddHHmmss')"

            # Create a new release pointing to the new revision
            Write-Host "Creating a new release '$releaseId' for revision '$ApiRevision'..."
            New-AzApiManagementApiRelease `
                -Context $apimContext `
                -ApiId $baseApiId `
                -ReleaseId $releaseId `
                -ApiRevision $ApiRevision
            Write-Host "Release '$releaseId' created and points to revision '$ApiRevision'."
        }
        catch {
            Write-Error "Failed to create or mark revision '$ApiRevision' as current. $_"
            exit 1
        }
    }
}

# Apply the policy to the current revision
Write-Host "Applying policy from file: $PolicyFilePath ..."
try {
    Set-AzApiManagementPolicy `
        -Context $apimContext `
        -ApiId $baseApiId `
        -PolicyFilePath $PolicyFilePath
    Write-Host "Policy set successfully."
}
catch {
    Write-Error "Failed to apply policy. $_"
    exit 1
}

# Cleanup old releases
Write-Host "Cleaning up old releases..."
try {
    $allReleases = Get-AzApiManagementApiRelease `
        -Context $apimContext `
        -ApiId $baseApiId

    # Exclude the most recent release
    $latestRelease = $allReleases | Sort-Object CreatedDateTime -Descending | Select-Object -First 1
    $oldReleases = $allReleases | Where-Object { $_.ReleaseId -ne $latestRelease.ReleaseId }

    foreach ($release in $oldReleases) {
        Write-Host "Deleting old release: $($release.ReleaseId)"
        Remove-AzApiManagementApiRelease `
            -Context $apimContext `
            -ApiId $baseApiId `
            -ReleaseId $release.ReleaseId
    }
    Write-Host "Old releases cleaned up successfully."
}
catch {
    Write-Error "Failed to clean up old releases. $_"
}

Write-Host "`nDeployment finished successfully!"

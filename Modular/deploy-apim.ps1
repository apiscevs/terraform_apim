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
            Write-Host "Marking revision '$ApiRevision' as current via release..."
            try {
                # Define release ID
                $releaseId = "my-api-release"
            
                # Check if the release exists
                $existingRelease = Get-AzApiManagementApiRelease `
                    -Context $apimContext `
                    -ApiId $baseApiId `
                    -ReleaseId $releaseId `
                    -ErrorAction SilentlyContinue
            
                if ($existingRelease) {
                    Write-Host "Existing release '$releaseId' found. Deleting it to update revision..."
                    
                    # Important Note:
                    # Attempting to update or create a release directly pointing to an already existing revision 
                    # did not work in our case. Azure API Management does not allow modifying the `ApiRevision`
                    # of an existing release, which caused this scenario to fail without any effect.
                    # To resolve this, we delete the existing release and recreate it pointing to the desired revision.
                    Remove-AzApiManagementApiRelease `
                        -Context $apimContext `
                        -ApiId $baseApiId `
                        -ReleaseId $releaseId
                    Write-Host "Deleted existing release '$releaseId'."
                }
            
                # Create a new release pointing to the desired revision
                Write-Host "Creating new release '$releaseId' for revision '$ApiRevision'..."
                New-AzApiManagementApiRelease `
                    -Context $apimContext `
                    -ApiId $baseApiId `
                    -ReleaseId $releaseId `
                    -ApiRevision $ApiRevision
            
                Write-Host "Revision '$ApiRevision' successfully marked as current via release."
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
            New-AzApiManagementApiRevision `
                -Context $apimContext `
                -ApiId $baseApiId `
                -ApiRevision $ApiRevision `
                -ApiRevisionDescription "Created by script."
            
            New-AzApiManagementApiRelease `
                -Context $apimContext `
                -ApiId $baseApiId `
                -ReleaseId "my-api-release" `
                -ApiRevision $ApiRevision `
                -Force

            Write-Host "Revision '$ApiRevision' created and marked as current."
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

Write-Host "`nDeployment finished successfully!"

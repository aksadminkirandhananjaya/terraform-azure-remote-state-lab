param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9]{3,24}$')]
    [string]$StateStorageAccount,
    [string]$StateResourceGroup = 'rg-tfstate-demo',
    [string]$StateLocation = 'eastus',
    [string]$StateContainer = 'tfstate'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI (az) was not found. Install it before running this script.'
}

# This script uses the currently selected Azure CLI subscription. The signed-in
# identity must be allowed to create the resource group/storage account and a role
# assignment. Subscription-level Owner is sufficient. Global Administrator by
# itself does not grant Azure subscription RBAC permissions.
az account show --output table
if ($LASTEXITCODE -ne 0) {
    throw 'Azure CLI is not authenticated. Run az login and select the intended subscription first.'
}

$subscriptionId = az account show --query id --output tsv
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($subscriptionId)) {
    throw 'Could not determine the active Azure subscription. Check the Azure CLI account context.'
}

$userObjectId = az ad signed-in-user show --query id --output tsv
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($userObjectId)) {
    throw 'Could not determine the signed-in user. Sign in with az login using the user identity that has the required Azure permissions.'
}

az group create --name $StateResourceGroup --location $StateLocation --output table
if ($LASTEXITCODE -ne 0) { throw 'Failed to create the state resource group.' }

az storage account create `
    --name $StateStorageAccount `
    --resource-group $StateResourceGroup `
    --location $StateLocation `
    --sku Standard_LRS `
    --kind StorageV2 `
    --https-only true `
    --min-tls-version TLS1_2 `
    --allow-blob-public-access false `
    --allow-shared-key-access false `
    --output table
if ($LASTEXITCODE -ne 0) { throw 'Failed to create the state storage account.' }

# Create the private container through the Azure Resource Manager control plane.
az storage container-rm create `
    --name $StateContainer `
    --storage-account $StateStorageAccount `
    --resource-group $StateResourceGroup `
    --public-access off `
    --output table
if ($LASTEXITCODE -ne 0) { throw 'Failed to create the private state container.' }

$containerScope = "/subscriptions/$subscriptionId/resourceGroups/$StateResourceGroup/providers/Microsoft.Storage/storageAccounts/$StateStorageAccount/blobServices/default/containers/$StateContainer"

# Grant the signed-in user blob data access only at this container scope.
# The identity needs Microsoft.Authorization/roleAssignments/write at this scope.
# Subscription-level Owner, User Access Administrator, or Role Based Access
# Control Administrator can provide the required role-assignment permission.
az role assignment create `
    --assignee-object-id $userObjectId `
    --assignee-principal-type User `
    --role 'Storage Blob Data Contributor' `
    --scope $containerScope `
    --output table
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to assign Storage Blob Data Contributor. Check that the Azure CLI identity has active role-assignment permission at this scope (for example, subscription-level Owner).'
}

Write-Host "`nState backend bootstrap complete."
Write-Host "Storage account: $StateStorageAccount"
Write-Host "Container: $StateContainer"
Write-Host "Container scope: $containerScope"
Write-Host 'Allow a few minutes for Azure RBAC changes to propagate before running Terraform.'
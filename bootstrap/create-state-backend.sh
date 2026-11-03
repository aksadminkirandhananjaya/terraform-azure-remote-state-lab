#!/usr/bin/env bash
set -euo pipefail

# Set STATE_STORAGE_ACCOUNT to a globally unique name (3-24 lowercase letters/numbers).
# Example: export STATE_STORAGE_ACCOUNT=sttfstateabc123xyz
STATE_RESOURCE_GROUP="${STATE_RESOURCE_GROUP:-rg-tfstate-demo}"
STATE_LOCATION="${STATE_LOCATION:-eastus}"
STATE_CONTAINER="${STATE_CONTAINER:-tfstate}"
: "${STATE_STORAGE_ACCOUNT:?Set STATE_STORAGE_ACCOUNT to a globally unique storage account name}"

if ! command -v az >/dev/null 2>&1; then
  printf 'Error: Azure CLI (az) was not found. Install it before running this script.\n' >&2
  exit 1
fi

# Use the currently selected Azure CLI subscription. The signed-in identity must
# have permission to create the resource group/storage account and role assignments.
# A subscription-level Owner assignment is sufficient. Global Administrator by
# itself does not grant Azure subscription RBAC permissions.
if ! az account show --output table; then
  printf 'Error: Azure CLI is not authenticated. Run az login and select the intended subscription.\n' >&2
  exit 1
fi

SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
if [[ -z "$SUBSCRIPTION_ID" ]]; then
  printf 'Error: Could not determine the active Azure subscription.\n' >&2
  exit 1
fi

USER_OBJECT_ID="$(az ad signed-in-user show --query id --output tsv)" || {
  printf 'Error: Could not determine the signed-in user. Sign in with az login using the user identity that has the required Azure permissions.\n' >&2
  exit 1
}
if [[ -z "$USER_OBJECT_ID" ]]; then
  printf 'Error: The signed-in user object ID is empty.\n' >&2
  exit 1
fi

az group create \
  --name "$STATE_RESOURCE_GROUP" \
  --location "$STATE_LOCATION" \
  --output table

az storage account create \
  --name "$STATE_STORAGE_ACCOUNT" \
  --resource-group "$STATE_RESOURCE_GROUP" \
  --location "$STATE_LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-shared-key-access false \
  --output table

# Create the container through the Azure Resource Manager control plane.
# Keep it private. It stores Terraform state, not public content.
az storage container-rm create \
  --name "$STATE_CONTAINER" \
  --storage-account "$STATE_STORAGE_ACCOUNT" \
  --resource-group "$STATE_RESOURCE_GROUP" \
  --public-access off \
  --output table

CONTAINER_SCOPE="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${STATE_RESOURCE_GROUP}/providers/Microsoft.Storage/storageAccounts/${STATE_STORAGE_ACCOUNT}/blobServices/default/containers/${STATE_CONTAINER}"

# Grant the signed-in user blob data access only at this container scope.
# The signed-in user needs Microsoft.Authorization/roleAssignments/write at this
# scope. Subscription-level Owner, User Access Administrator, or Role Based Access
# Control Administrator can provide the required role-assignment permission.
if ! az role assignment create \
  --assignee-object-id "$USER_OBJECT_ID" \
  --assignee-principal-type User \
  --role "Storage Blob Data Contributor" \
  --scope "$CONTAINER_SCOPE" \
  --output table; then
  printf '\nError: Failed to assign Storage Blob Data Contributor.\n' >&2
  printf 'Check that the Azure CLI identity has active role-assignment permission at this scope (for example, subscription-level Owner).\n' >&2
  exit 1
fi

printf '\nState backend bootstrap complete.\n'
printf 'Storage account: %s\nContainer: %s\nContainer scope: %s\n' "$STATE_STORAGE_ACCOUNT" "$STATE_CONTAINER" "$CONTAINER_SCOPE"
printf 'Allow a few minutes for Azure RBAC changes to propagate before running Terraform.\n'
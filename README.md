# Terraform Azure Remote State Lab

![Terraform](https://img.shields.io/badge/Terraform-1.5%2B-7B42BC?logo=terraform)
![Azure](https://img.shields.io/badge/Cloud-Microsoft%20Azure-0078D4?logo=microsoftazure)
![Infrastructure as Code](https://img.shields.io/badge/IaC-Infrastructure%20as%20Code-blue)
![License](https://img.shields.io/badge/License-MIT-green)

## Project Overview

This project demonstrates how to configure and migrate Terraform state from a local backend to a remote backend using **Azure Blob Storage**.

The project uses Microsoft Entra ID authentication and Azure Role-Based Access Control (RBAC) to securely access the remote state without storing Storage Account Access Keys in Terraform configuration.

It also demonstrates how Azure Blob Storage provides state locking to help prevent conflicting Terraform operations when multiple engineers work with the same infrastructure state.

## Objectives

- Create an Azure Storage Account for Terraform remote state.
- Configure a private Azure Blob Storage container.
- Implement Microsoft Entra ID authentication.
- Assign Storage Blob Data Contributor permissions using Azure RBAC.
- Deploy Azure infrastructure using Terraform.
- Migrate existing local Terraform state to Azure Blob Storage.
- Verify remote state synchronization.
- Understand and test Terraform state locking.

## Architecture

The project creates two separate Azure Resource Groups.

1. `rg-tfstate-demo`: Contains the Storage Account used for remote Terraform state.
2. `rg-terraform-demo`: Contains the infrastructure managed by Terraform.

### Architecture Diagram

```text
                  Microsoft Azure
                         |
             +-----------+-----------+
             |                       |
       rg-tfstate-demo       rg-terraform-demo
             |                       |
      Storage Account          Terraform Resources
             |                       |
       Blob Container          Resource Group
             |                       |
    networking/terraform.tfstate  Virtual Network
             |
      Azure Blob Storage
       Remote State
             |
       State Locking
```

### Remote Backend Configuration

| Component | Value |
|---|---|
| Backend | AzureRM |
| Storage Service | Azure Blob Storage |
| Container | tfstate |
| State File | networking/terraform.tfstate |
| Authentication | Microsoft Entra ID |
| Authorization | Azure RBAC |
| Access Role | Storage Blob Data Contributor |

## Technologies Used

| Technology | Purpose |
|---|---|
| Terraform | Infrastructure as Code |
| Microsoft Azure | Cloud infrastructure |
| Azure CLI | Azure authentication and resource management |
| Azure Blob Storage | Remote Terraform state |
| Microsoft Entra ID | Identity authentication |
| Azure RBAC | Access control |
| Git | Version control |
| GitHub | Source code management |
| VS Code | Development environment |

## Repository Structure

```text
terraform-azure-remote-state-lab/
│
├── bootstrap/
│   ├── create-state-backend.sh
│   └── create-state-backend.ps1
│
├── infrastructure/
│   ├── versions.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── outputs.tf
│   └── backend.tf
│
├── .gitignore
└── README.md
```

The `backend.hcl` file is created locally and excluded from Git because it contains environment-specific backend configuration.

## Prerequisites

Install the following tools before starting:

- [Terraform](https://developer.hashicorp.com/terraform/install)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Git](https://git-scm.com/downloads)
- [Visual Studio Code](https://code.visualstudio.com/)

You also need:

- An active Azure subscription.
- An Azure identity with permission to create the required resources.
- Permission to create Azure role assignments.
- Storage Blob Data Contributor access to the state container.

## Implementation Guide

### Step 1: Authenticate with Azure

Sign in using Azure CLI:

```bash
az login
```

Check available subscriptions:

```bash
az account list --output table
```

Select the subscription you want to use:

```bash
az account set --subscription "<subscription-id>"
```

Verify the active subscription:

```bash
az account show --output table
```

### Step 2: Create the Remote State Backend

Navigate to the bootstrap directory:

```bash
cd bootstrap
```

Set the Storage Account name:

```bash
export STATE_STORAGE_ACCOUNT=youruniquestorageaccount
```

Optionally configure the resource group and region:

```bash
export STATE_RESOURCE_GROUP=rg-tfstate-demo
export STATE_LOCATION=eastus
```

Make the Bash script executable:

```bash
chmod +x create-state-backend.sh
```

Run the bootstrap script:

```bash
./create-state-backend.sh
```

The script creates:

- Azure Resource Group.
- Azure Storage Account.
- Private Blob Storage container.
- Storage Blob Data Contributor role assignment.

For Windows, use the PowerShell script:

```powershell
.\create-state-backend.ps1 -StateStorageAccount "youruniquestorageaccount"
```

### Step 3: Deploy Infrastructure Using Local State

Navigate to the infrastructure directory:

```bash
cd ../infrastructure
```

Format the Terraform files:

```bash
terraform fmt
```

Initialize Terraform:

```bash
terraform init
```

Validate the configuration:

```bash
terraform validate
```

Generate an execution plan:

```bash
terraform plan
```

Deploy the infrastructure:

```bash
terraform apply
```

Review the execution plan and confirm when prompted.

### Step 4: Configure Azure Remote Backend

The backend configuration is defined in `backend.tf`:

```hcl
terraform {
  backend "azurerm" {}
}
```

Create a local `backend.hcl` file:

```hcl
storage_account_name = "youruniquestorageaccount"
container_name       = "tfstate"
key                  = "networking/terraform.tfstate"
use_azuread_auth     = true
use_cli              = true
```

Replace the Storage Account name and container name with the values used during bootstrap.

### Step 5: Back Up Existing Terraform State

Before migrating the state, create a backup:

```bash
cp terraform.tfstate terraform.tfstate.pre-migration.backup
```

Keep this backup secure. Never commit it to GitHub.

### Step 6: Migrate Local State to Azure Blob Storage

Run:

```bash
terraform init -migrate-state -backend-config=backend.hcl
```

Terraform detects the backend change and prompts you to migrate the existing state.

Confirm the migration.

Terraform transfers the existing state to Azure Blob Storage without recreating the managed resources.

### Step 7: Verify Remote State

List the resources tracked by Terraform:

```bash
terraform state list
```

Generate a new execution plan:

```bash
terraform plan
```

If no infrastructure changes have occurred, Terraform should report that no changes are required.

Verify the state blob:

```bash
az storage blob list \
  --account-name "youruniquestorageaccount" \
  --container-name tfstate \
  --auth-mode login \
  --output table
```

You should see:

```text
networking/terraform.tfstate
```

### Step 8: Understand State Locking

AzureRM backend uses Azure Blob Storage native locking and consistency mechanisms.

When Terraform performs an operation requiring a state lock, it coordinates access to the state blob.

This helps prevent conflicting operations from modifying the same state simultaneously.

No separate locking service is required.

### Step 9: Cleanup

To remove the demo infrastructure while keeping the remote backend:

```bash
terraform destroy
```

Review the execution plan before confirming.

The Terraform-managed Resource Group and Virtual Network will be deleted. The separately created remote state Storage Account and container will remain.

Only remove the backend after verifying that no other Terraform project depends on it.

## Security Best Practices

- Use Microsoft Entra ID authentication instead of Storage Account Access Keys.
- Apply least-privilege Azure RBAC permissions.
- Keep the state container private.
- Never commit Terraform state files to GitHub.
- Never commit state backups.
- Exclude local backend configuration files.
- Keep `.terraform.lock.hcl` under version control.
- Avoid committing sensitive `.tfvars` files.
- Review Terraform plans before applying changes.
- Protect remote state storage with appropriate Azure security and recovery controls.

## Learning Outcomes

After completing this project, you should understand:

- Terraform local and remote backends.
- Azure Blob Storage remote state configuration.
- Microsoft Entra ID authentication.
- Azure RBAC role assignments.
- Terraform state migration.
- Terraform state locking.
- Terraform infrastructure deployment and cleanup.
- Secure infrastructure state management.

## Future Improvements

- Implement GitHub Actions for Terraform CI/CD.
- Configure GitHub Actions authentication with Azure using OpenID Connect.
- Add automated Terraform formatting and validation.
- Add automated Terraform plan checks.
- Implement separate development and production environments.
- Add Azure Storage network restrictions and recovery protection.

## Author

**Kiran Dhananjaya**

GitHub: [@aksadminkirandhananjaya](https://github.com/aksadminkirandhananjaya)

## License

This project is licensed under the MIT License. See the LICENSE file for details.

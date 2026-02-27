# Get-AzureBackupStatus.ps1

A PowerShell script that lists **all Azure Backup–enabled resources** and their status across Recovery Services vaults and Backup vaults (Data Protection). It reports protection status, last backup time (in Central US time), retention, when backup data expires, and whether soft delete is enabled.

Use it for reporting, audits, or to quickly see what is protected and when it will be deleted.

---

## What it does

- **Recovery Services vaults**  
  Lists backup items for:
  - **Azure VMs** (OS and data disks)
  - **Azure File shares** (Azure Files)

- **Backup vaults (Data Protection)**  
  Lists backup instances for:
  - **Azure Blob storage** (operational / point-in-time restore)

For each item you get:

| Column | Description |
|--------|-------------|
| **ResourceType** | Azure VM, Azure File Share, or Blob Storage |
| **ResourceName** | Name of the VM, file share, or storage account |
| **VaultName** | Vault that holds the backup |
| **ProtectionStatus** | e.g. Protected, ProtectionStopped |
| **HealthStatus** | e.g. Healthy, IRPending |
| **LastBackupStatus** | e.g. Completed, Failed |
| **LastBackupTime** | Last backup in **Central (US)** time, or "Never" / "N/A (continuous PITR)" for blobs |
| **Retention** | How long backups are kept (e.g. "30 days") |
| **ExpiresOrDeleteBy** | When the oldest recovery point will be deleted (Central time), or "N/A (PITR)" for blobs |
| **SoftDelete** | Whether vault soft delete is Enabled (with days) or Disabled |
| **PolicyName** | Backup policy name |

---

## Prerequisites

- **PowerShell** 5.1 or PowerShell 7+ (Windows, macOS, or Linux).
- **Azure CLI** (`az`) installed and logged in:
  ```bash
  az login
  ```
  Optional: set the subscription to use:
  ```bash
  az account set --subscription "Your Subscription Name"
  ```
- **Permissions**: Your account must be able to read backup vaults and backup items (e.g. **Reader** or **Backup Reader** on the vaults and resource groups).

---

## Usage

### Basic (current subscription, all vaults)

```powershell
.\Get-AzureBackupStatus.ps1
```

### Limit to a resource group

```powershell
.\Get-AzureBackupStatus.ps1 -ResourceGroup "my-backup-rg"
```

### Export results to CSV

```powershell
.\Get-AzureBackupStatus.ps1 -ExportCsv ".\backup-report.csv"
```

### Limit to specific vault(s)

```powershell
# Only Recovery Services vault "my-rsv"
.\Get-AzureBackupStatus.ps1 -RecoveryServicesVaultName "my-rsv"

# Only Backup vault (Data Protection) "my-bv"
.\Get-AzureBackupStatus.ps1 -BackupVaultName "my-bv"
```

### Use a specific subscription

```powershell
.\Get-AzureBackupStatus.ps1 -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### Quiet output (table only, no progress lines)

```powershell
.\Get-AzureBackupStatus.ps1 -Quiet
```

### Get help

```powershell
Get-Help .\Get-AzureBackupStatus.ps1 -Full
```

---

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **SubscriptionId** | string | (empty) | Azure subscription ID. Empty = current subscription. |
| **ResourceGroup** | string | (empty) | Limit to this resource group. Empty = all. |
| **RecoveryServicesVaultName** | string | (empty) | Limit to this Recovery Services vault. Empty = all. |
| **BackupVaultName** | string | (empty) | Limit to this Backup vault (Data Protection). Empty = all. |
| **ExportCsv** | string | (empty) | File path to export results as CSV. Empty = no export. |
| **Quiet** | switch | false | Suppress progress messages; only the table (and optional export) is shown. |

---

## Notes

- **Dates and times**  
  All displayed backup and expiry times are in **Central (US)** time (CST/CDT).

- **Blob backup**  
  Blob operational backup uses **point-in-time restore (PITR)**. There are no discrete backup jobs, so:
  - **LastBackupTime** shows `N/A (continuous PITR)`.
  - **ExpiresOrDeleteBy** shows `N/A (PITR)`.
  - **Retention** still comes from the backup policy (e.g. "30 days").

- **Soft delete**  
  - **Recovery Services**: From vault backup properties (`softDeleteFeatureState`, retention in days when available).
  - **Backup vault (Data Protection)**: From vault security settings (`softDeleteSettings`).
  Values are shown as **Enabled (N days)** or **Disabled** (or **AlwaysOn** where applicable).

- **Azure CLI**  
  The script calls Azure CLI. If you see a one-time message about a preview extension (e.g. for `dataprotection`), you can ignore it; the script still runs.

---

## Example output

```
Subscription: My Subscription (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)

--- Recovery Services vaults (VMs + Azure File shares) ---
  Vault: my-rsv (RG: my-rg)

--- Backup vaults / Data Protection (Blobs) ---
  Vault: my-bv (RG: my-rg)

--- Summary ---

ResourceType   ResourceName   VaultName  ProtectionStatus  HealthStatus  LastBackupStatus  LastBackupTime           Retention  ExpiresOrDeleteBy        SoftDelete      PolicyName
-------------  -------------  ---------  ----------------  ------------  ----------------  -----------------------  ---------  -----------------------  --------------  ----------
Azure VM       myvm01        my-rsv     Protected         Healthy       Completed         Feb 26, 2025 2:30 PM CST 30 days    Mar 28, 2025 2:30 PM CST Enabled (14 days) DefaultPolicy
Blob Storage   mystorage     my-bv      ProtectionConfig  Succeeded     ProtectionConfig  N/A (continuous PITR)   30 days    N/A (PITR)                Enabled (14 days) Default-blobs

Total items: 2
```

---

## License and disclaimer

This script is provided as-is for reporting and operational visibility over Azure Backup. It only **reads** backup metadata via Azure CLI; it does not create, modify, or delete any Azure resources. Use it in accordance with your organization’s security and compliance policies.

You can share and adapt the script; if you redistribute it, keeping this README (or equivalent documentation) with the script is recommended.

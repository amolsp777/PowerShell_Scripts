<#
.SYNOPSIS
    Lists all backup-enabled Azure resources and their backup status (VMs, file shares, blobs).

.DESCRIPTION
    Queries Azure Recovery Services vaults and Backup vaults (Data Protection) to show protected
    items, last backup time, retention, expiry, soft delete settings, and health.
    Requires Azure CLI (az) and run after: az login

.PARAMETER SubscriptionId
    Subscription ID. Empty = current subscription.

.PARAMETER ResourceGroup
    Limit to this resource group. Empty = all resource groups in subscription.

.PARAMETER RecoveryServicesVaultName
    Limit to this Recovery Services vault. Empty = all RS vaults in scope.

.PARAMETER BackupVaultName
    Limit to this Backup vault (Data Protection). Empty = all Backup vaults in scope.

.PARAMETER ExportCsv
    Path to export results to CSV (e.g. .\backup-status.csv). Empty = no export.

.PARAMETER Quiet
    Suppress progress messages; output table only.

.EXAMPLE
    .\Get-AzureBackupStatus.ps1

.EXAMPLE
    .\Get-AzureBackupStatus.ps1 -ResourceGroup "my-rg" -ExportCsv ".\backup-report.csv"

.EXAMPLE
    .\Get-AzureBackupStatus.ps1 -RecoveryServicesVaultName "my-rsv" -Quiet
#>

[CmdletBinding()]
param(
    [string] $SubscriptionId = '',
    [string] $ResourceGroup = '',
    [string] $RecoveryServicesVaultName = '',
    [string] $BackupVaultName = '',
    [string] $ExportCsv = '',
    [switch] $Quiet
)

$ErrorActionPreference = 'Stop'

# Suppress Azure CLI preview extension warnings
$prevErr = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

function Write-Status { param([string]$Msg) if (-not $Quiet) { Write-Host $Msg } }

# Format UTC/ISO datetime to Central (US) time, readable (e.g. "Feb 26, 2025 3:45 PM CST")
function Format-ToCentralTime {
    param([string]$DateTimeString)
    if (-not $DateTimeString) { return 'Never' }
    try {
        $utc = [DateTime]::Parse($DateTimeString, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
        if ($utc.Kind -eq [DateTimeKind]::Unspecified) { $utc = [DateTime]::SpecifyKind($utc, [DateTimeKind]::Utc) }
        $central = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($utc, 'Central Standard Time')
        $tz = if ($central.IsDaylightSavingTime()) { 'CDT' } else { 'CST' }
        $central.ToString("MMM d, yyyy h:mm tt", [System.Globalization.CultureInfo]::InvariantCulture) + " $tz"
    } catch {
        $DateTimeString
    }
}

# Convert UTC/ISO datetime string to DateTime for calculations
function Get-UtcDateTime {
    param([string]$DateTimeString)
    if (-not $DateTimeString) { return $null }
    try {
        $utc = [DateTime]::Parse($DateTimeString, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
        if ($utc.Kind -eq [DateTimeKind]::Unspecified) { $utc = [DateTime]::SpecifyKind($utc, [DateTimeKind]::Utc) }
        return $utc
    } catch { return $null }
}

# Get retention days from Recovery Services backup policy JSON
function Get-RSPolicyRetentionDays {
    param([string]$PolicyJson)
    if (-not $PolicyJson) { return $null }
    try {
        $p = $PolicyJson | ConvertFrom-Json
        $rp = $p.properties.retentionPolicy
        if (-not $rp) { return $null }
        $daily = $rp.dailySchedule
        if ($daily -and $daily.retentionDuration) {
            $count = [int]$daily.retentionDuration.count
            $dur = $daily.retentionDuration.durationType
            if ($dur -eq 'Days') { return $count }
            if ($dur -eq 'Weeks') { return $count * 7 }
            if ($dur -eq 'Months') { return $count * 30 }
            if ($dur -eq 'Years') { return $count * 365 }
            return $count
        }
        return $null
    } catch { return $null }
}

# Parse ISO duration (e.g. P30D) to days
function Get-DurationDays {
    param([string]$Duration)
    if (-not $Duration) { return $null }
    if ($Duration -match 'P(\d+)D') { return [int]$Matches[1] }
    if ($Duration -match 'P(\d+)W') { return [int]$Matches[1] * 7 }
    if ($Duration -match 'P(\d+)M') { return [int]$Matches[1] * 30 }
    if ($Duration -match 'P(\d+)Y') { return [int]$Matches[1] * 365 }
    return $null
}

function Get-AzJson {
    param([string]$Command)
    try {
        $json = Invoke-Expression "az $Command 2>`$null"
        if ($json) { $json | ConvertFrom-Json } else { $null }
    } catch { $null }
}

# --- Subscription ---
if ($SubscriptionId) {
    Write-Status "Setting subscription: $SubscriptionId"
    az account set --subscription $SubscriptionId 2>$null
}

$account = Get-AzJson "account show"
if (-not $account) { throw "Not logged in or az CLI failed. Run: az login" }
$subId = $account.id
$subName = $account.name
Write-Status "Subscription: $subName ($subId)`n"

$ErrorActionPreference = $prevErr

$allResults = [System.Collections.ArrayList]@()

# ========== Recovery Services vaults (VMs + File shares) ==========
Write-Status "--- Recovery Services vaults (VMs + Azure File shares) ---"

$rsvArgs = @('backup', 'vault', 'list', '-o', 'json')
if ($ResourceGroup) { $rsvArgs += '--resource-group', $ResourceGroup }
$rsvRaw = az @rsvArgs 2>$null
if (-not $rsvRaw) { $rsvList = @() } else {
    $rsvList = $rsvRaw | ConvertFrom-Json
    if ($rsvList -isnot [Array]) { $rsvList = @($rsvList) }
}

foreach ($vault in $rsvList) {
    $rg = $vault.resourceGroup
    $vaultName = $vault.name
    if ($RecoveryServicesVaultName -and $vaultName -ne $RecoveryServicesVaultName) { continue }

    Write-Status "  Vault: $vaultName (RG: $rg)"

    # Vault soft delete (once per vault)
    $rsvPropsJson = az backup vault backup-properties show --name $vaultName --resource-group $rg -o json 2>$null
    $softDeleteState = '-'
    $softDeleteDays = ''
    if ($rsvPropsJson) {
        try {
            $vp = $rsvPropsJson | ConvertFrom-Json
            $p = if ($vp.properties) { $vp.properties } else { $vp }
            $sd = $p.softDeleteFeatureState
            $sdDur = $p.softDeleteRetentionDurationInDays
            if ($sd) {
                $softDeleteState = $sd
                $softDeleteDays = if ($sdDur) { " ($sdDur days)" } else { '' }
            }
        } catch { }
    }
    $softDeleteDisplay = if ($softDeleteState -eq '-' -or $softDeleteState -eq 'Disabled') { 'Disabled' } else { "Enabled$softDeleteDays" }
    $policyRetentionCache = @{}

    # Containers: AzureIaasVM and AzureStorage
    foreach ($mgmtType in @('AzureIaasVM', 'AzureStorage')) {
        $containersJson = az backup container list --resource-group $rg --vault-name $vaultName --backup-management-type $mgmtType --query "[]" -o json 2>$null
        if (-not $containersJson) { continue }
        $containers = $containersJson | ConvertFrom-Json
        if ($containers -isnot [Array]) { $containers = @($containers) }
        foreach ($container in $containers) {
            $containerName = $container.name

            $itemsJson = az backup item list --resource-group $rg --vault-name $vaultName --backup-management-type $mgmtType --container-name $containerName --query "[]" -o json 2>$null
            if (-not $itemsJson) { continue }
            $items = $itemsJson | ConvertFrom-Json
            if ($items -isnot [Array]) { $items = @($items) }
            foreach ($item in $items) {
                $props = $item.properties
                $itemName = $item.name
                $friendlyName = if ($props.friendlyName) { $props.friendlyName } else { $itemName }
                $protectionStatus = if ($props.protectionStatus) { $props.protectionStatus } else { '-' }
                $lastBackupStatus = if ($props.lastBackupStatus) { $props.lastBackupStatus } else { '-' }
                $lastBackupTime = Format-ToCentralTime $props.lastBackupTime
                $healthStatus = if ($props.healthStatus) { $props.healthStatus } else { '-' }
                $workloadType = if ($props.workloadType) { $props.workloadType } else { 'Unknown' }

                $resourceType = switch -Regex ($workloadType) { 'VM' { 'Azure VM' } 'AzureFileShare' { 'Azure File Share' } default { $workloadType } }

                $policyName = if ($props.policyId) { ($props.policyId -replace '^.*/', '') } else { '-' }
                $retentionDays = $null
                $expiresOrDeleteDate = '-'
                if ($policyName -and $policyName -ne '-') {
                    if (-not $policyRetentionCache[$policyName]) {
                        $polJson = az backup policy show --name $policyName --resource-group $rg --vault-name $vaultName -o json 2>$null
                        $policyRetentionCache[$policyName] = Get-RSPolicyRetentionDays $polJson
                    }
                    $retentionDays = $policyRetentionCache[$policyName]
                }
                $retentionDisplay = if ($retentionDays) { "$retentionDays days" } else { '-' }
                if ($retentionDays -and $props.lastBackupTime) {
                    $lastUtc = Get-UtcDateTime $props.lastBackupTime
                    if ($lastUtc) {
                        $expiresUtc = $lastUtc.AddDays($retentionDays)
                        $expiresOrDeleteDate = Format-ToCentralTime $expiresUtc.ToString('o')
                    }
                }
                [void]$allResults.Add([PSCustomObject]@{
                    VaultType          = 'Recovery Services'
                    VaultName          = $vaultName
                    ResourceGroup      = $rg
                    ResourceType       = $resourceType
                    ResourceName       = $friendlyName
                    ItemId             = $itemName
                    ProtectionStatus   = $protectionStatus
                    HealthStatus       = $healthStatus
                    LastBackupStatus   = $lastBackupStatus
                    LastBackupTime     = $lastBackupTime
                    Retention          = $retentionDisplay
                    ExpiresOrDeleteBy  = $expiresOrDeleteDate
                    SoftDelete         = $softDeleteDisplay
                    PolicyName         = $policyName
                })
            }
        }
    }
}

# ========== Backup vaults - Data Protection (Blobs) ==========
# Blob operational backup uses continuous PITR (point-in-time restore); there are no discrete backup jobs, so no "last backup" timestamp.
Write-Status "`n--- Backup vaults / Data Protection (Blobs) ---"

$bvArgs = @('dataprotection', 'backup-vault', 'list', '-o', 'json')
if ($ResourceGroup) { $bvArgs += '--resource-group', $ResourceGroup }
$ErrorActionPreference = 'SilentlyContinue'
$bvListJson = az @bvArgs 2>$null
$ErrorActionPreference = $prevErr
if ($bvListJson) {
    $bvList = $bvListJson | ConvertFrom-Json
    if ($bvList -isnot [Array]) { $bvList = @($bvList) }
} else {
    $bvList = @()
}

foreach ($vault in $bvList) {
    $rg = $vault.resourceGroup
    $vaultName = $vault.name
    if ($BackupVaultName -and $vaultName -ne $BackupVaultName) { continue }

    Write-Status "  Vault: $vaultName (RG: $rg)"

    # Backup vault soft delete (Data Protection)
    $ErrorActionPreference = 'SilentlyContinue'
    $bvShowJson = az dataprotection backup-vault show --resource-group $rg --vault-name $vaultName -o json 2>$null
    $ErrorActionPreference = $prevErr
    $bvSoftDelete = 'Disabled'
    if ($bvShowJson) {
        try {
            $bv = $bvShowJson | ConvertFrom-Json
            $sd = $bv.properties.securitySettings.softDeleteSettings
            if ($sd) {
                $sdState = $sd.state
                $sdDays = $sd.retentionDurationInDays
                if ($sdState) { $bvSoftDelete = if ($sdDays) { "Enabled ($sdDays days)" } else { "Enabled" } }
            }
        } catch { }
    }

    $ErrorActionPreference = 'SilentlyContinue'
    $instancesJson = az dataprotection backup-instance list --resource-group $rg --vault-name $vaultName --query "[]" -o json 2>$null
    $ErrorActionPreference = $prevErr
    if (-not $instancesJson) { continue }
    $instances = $instancesJson | ConvertFrom-Json
    if ($instances -isnot [Array]) { $instances = @($instances) }
    foreach ($bi in $instances) {
        $name = $bi.name
        $dsInfo = $bi.properties.dataSourceInfo
        $policyInfo = $bi.properties.policyInfo
        $currentProtection = $bi.properties.currentProtectionState
        $protectionStatus = $bi.properties.protectionStatus
        $provisioningState = $bi.properties.provisioningState
        $resourceName = if ($dsInfo.resourceName) { $dsInfo.resourceName } else { $name }
        $policyName = if ($policyInfo.policyId) { $policyInfo.policyId -replace '^.*/', '' } else { '-' }
        $statusStr = if ($protectionStatus -is [string]) { $protectionStatus } else { $protectionStatus.status }

        $retentionDisplay = '-'
        if ($policyName -and $policyName -ne '-') {
            $ErrorActionPreference = 'SilentlyContinue'
            $polJson = az dataprotection backup-policy show --resource-group $rg --vault-name $vaultName --name $policyName -o json 2>$null
            $ErrorActionPreference = $prevErr
            if ($polJson) {
                try {
                    $pol = $polJson | ConvertFrom-Json
                    $rules = $pol.properties.policyRules
                    if ($rules) {
                        foreach ($r in @($rules)) {
                            if ($r.lifecycles) {
                                foreach ($lc in @($r.lifecycles)) {
                                    if ($lc.deleteAfter -and $lc.deleteAfter.duration) {
                                        $days = Get-DurationDays $lc.deleteAfter.duration
                                        if ($null -ne $days) { $retentionDisplay = "$days days"; break }
                                    }
                                }
                            }
                        }
                    }
                } catch { }
            }
        }

        [void]$allResults.Add([PSCustomObject]@{
            VaultType          = 'Backup (Data Protection)'
            VaultName          = $vaultName
            ResourceGroup      = $rg
            ResourceType      = 'Blob Storage'
            ResourceName      = $resourceName
            ItemId            = $name
            ProtectionStatus  = $currentProtection
            HealthStatus     = $provisioningState
            LastBackupStatus  = $statusStr
            LastBackupTime    = 'N/A (continuous PITR)'
            Retention         = $retentionDisplay
            ExpiresOrDeleteBy = 'N/A (PITR)'
            SoftDelete        = $bvSoftDelete
            PolicyName        = $policyName
        })
    }
}

# ========== Output ==========
Write-Status "`n--- Summary ---"

if ($allResults.Count -eq 0) {
    Write-Host "No backup-enabled resources found in scope."
    if ($ResourceGroup) { Write-Host "  (Resource group filter: $ResourceGroup)" }
    exit 0
}

$allResults | Format-Table -AutoSize -Property ResourceType, ResourceName, VaultName, ProtectionStatus, HealthStatus, LastBackupStatus, LastBackupTime, Retention, ExpiresOrDeleteBy, SoftDelete, PolicyName

Write-Host "`nTotal items: $($allResults.Count)"

if ($ExportCsv) {
    $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ExportCsv)
    $allResults | Export-Csv -Path $resolvedPath -NoTypeInformation -Encoding UTF8
    Write-Host "Exported to: $resolvedPath"
}

# Return for pipeline
$allResults

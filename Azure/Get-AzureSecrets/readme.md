# Azure

# Azure Key Vault Secrets Retrieval Script

This PowerShell script retrieves all secrets from each Key Vault in each subscription in your Azure account. The script outputs the details of each secret, including the subscription name, Key Vault name, secret name, secret value, creation date, and last updated date.

## Prerequisites

- Azure PowerShell module installed
- Logged in to your Azure account with sufficient permissions to access Key Vaults and secrets

## Usage

1. Clone this repository or download the script file.
2. Open a PowerShell terminal.
3. Run the script using the following command:

    ```powershell
    .\Get-AzKeyVaultSecrets.ps1
    ```

## Script

```powershell
# Login to Azure
Connect-AzAccount

# Get all subscriptions
$subscriptions = Get-AzSubscription

# Initialize an array to store the results
$results = @()

foreach ($subscription in $subscriptions) {
    # Set the current subscription
    Set-AzContext -SubscriptionId $subscription.Id

    # Get all Key Vaults in the current subscription
    $keyVaults = Get-AzKeyVault

    foreach ($keyVault in $keyVaults) {
        try {
            # Get all secrets in the current Key Vault
            $secrets = Get-AzKeyVaultSecret -VaultName $keyVault.VaultName

            foreach ($secret in $secrets) {
                # Create a custom object for each secret
                $result = [PSCustomObject]@{
                    Subscription = $subscription.Name
                    KeyVault     = $keyVault.VaultName
                    SecretName   = $secret.Name
                    SecretValue  = $secret.SecretValueText
                    Created      = $secret.Attributes.Created
                    Updated      = $secret.Attributes.Updated
                }
                # Add the custom object to the results array
                $results += $result
            }
        } catch {
            Write-Output "Failed to access secrets in Key Vault: $($keyVault.VaultName) in Subscription: $($subscription.Name). Error: $_"
        }
    }
}

# Output the results in a table format
$results | Format-Table -AutoSize
```
## Error Handling
The script includes error handling to skip over Key Vaults where access is forbidden. If you encounter a “Forbidden” error, ensure that your account has the necessary permissions to access the Key Vaults and their secrets.

## Permissions
To assign the necessary permissions, you can use the following PowerShell commands:

```powershell
# Assign the Key Vault Secrets User role to your account
$vaultName = "YourKeyVaultName"
$userId = (Get-AzADUser -UserPrincipalName "your-email@example.com").Id
New-AzKeyVaultAccessPolicy -VaultName $vaultName -ObjectId $userId -PermissionsToSecrets get,list

```
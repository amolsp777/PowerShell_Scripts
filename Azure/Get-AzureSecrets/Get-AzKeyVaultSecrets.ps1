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
                    Created      = $secret.Created
                    Updated      = $secret.Updated
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

$results | Out-HtmlView  -Title "Azure KV Secrets" -Filtering -OrderMulti  -SearchPane -SearchPaneLocation bottom -SearchRegularExpression 
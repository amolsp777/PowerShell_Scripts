###############################################
# Author: Amol
# Date: '$(Get-Date)'
# Description: Check monthly patch Tuesday released patches. 
###############################################
# Requires: MsrcSecurityUpdates module, Out-HtmlView module



# Check if the module is already installed
if (-not (Get-Module -ListAvailable -Name MsrcSecurityUpdates)) {
    Write-Host "Installing MsrcSecurityUpdates module..."
    Install-Module -Name MsrcSecurityUpdates -Force -SkipPublisherCheck
} else {
    Write-Host "MsrcSecurityUpdates module is already installed. Skipping installation."
}

Import-Module MsrcSecurityUpdates

# Example: Get the Feb 2021 CVRF document (replace with latest ID)
$docId = "2025-Sep"

# Example: February 2021 release
$msTuePatches = Get-MsrcCvrfDocument -ID $docId  | Get-MsrcCvrfAffectedSoftware 

#$msTuePatches | Select-Object CVE,Severity,Weakness,Impact,'Customer Action Required',RestartRequired,KBArticle,FullProductName,Supercedence | ft

#$msTuePatches | Out-HtmlView -SearchPane -Filtering 

$msTuePatches | select -First 1



# List of product names to skip
$excludeProducts = @(
    "Windows Server 2012",
    "Office 2013",
    "Windows Server 2008*" ,
    "Azure*",
    "azl*",
    "cbl2*",
    "Xbox Gaming Services*",
    "Microsoft * 2016 *" # Remove excel,word,powerpoint 2016.
)

$msTuePatches |
Where-Object {
    # handle if FullProductName is an array
    $fullNames = @($_.FullProductName) 
    -not ($fullNames | Where-Object { $name = $_; $excludeProducts | Where-Object { $name -like $_ } })
} |
    Select-Object `
        CVE,
        Severity,
        Weakness,
        Impact,
        @{Name='CustomerActionRequired';Expression={ ($_.'Customer Action Required' -join ', ') }},
        @{Name='RestartRequired';Expression={ ($_.RestartRequired -join ', ') }},
        @{Name = 'KBArticleID'; Expression = { $_.KBArticle.ID }},
        @{Name = 'KBArticleURL'; Expression = { $_.KBArticle.URL }},
        @{Name = 'KBArticleSubType'; Expression = { $_.KBArticle.SubType }},
        @{Name='FullProductName';Expression={ ($_.FullProductName -join '; ') }},
        @{Name='Supercedence';Expression={ ($_.Supercedence -join ', ') }} | Out-HtmlView -SearchPane -SearchPaneLocation bottom -Filtering


<#
.SYNOPSIS
    
.DESCRIPTION
    This script is to get the Cert Expiry details from provided URLs
.NOTES
    This can run on any Windws OS
    Amol Patil 
.LINK
    
.EXAMPLE

#>

$SCRIPT_PARENT = Split-Path -Parent $MyInvocation.MyCommand.Definition

$Urls = @()
<#
$Urls = "https://example.com/",
        "https://google.com/"
#>

# Create sites.txt file at the location where this script is saved and will execute.
# Enter the required sites in that file in each line.
# This script will pick the each site and check the cert.
# comment below line you you want to take urls within this code. from above commneted part. 

# $Urls = Get-Content ($SCRIPT_PARENT + "\sites.txt")

$Urls = Import-Csv ($SCRIPT_PARENT + "\CertSites.csv")

Write-Host "Checking certs on sites..." -ForegroundColor Yellow

$props = @()

[int]$MinimumCertAgeDays = 60

$ErrorActionPreference = 'silentlycontinue'

Foreach ($urlin in $Urls) {

	$url = $urlin.url

	Write-Host "Checking certs on site [ $url]" -ForegroundColor Yellow
	[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
	
	$req = [Net.HttpWebRequest]::Create($url)
	$req.GetResponse() | Out-Null
	#$req.ServicePoint.Certificate.GetExpirationDateString()
	
	$ExpirationDate = $req.ServicePoint.Certificate.GetExpirationDateString()
	$certissuer = $req.ServicePoint.Certificate.Issuer
	$DayCount = ($(Get-date $ExpirationDate) - $(Get-Date)).Days
	
	If ($DayCount -le 0) { $certstatus = "Expired" }
	elseif (($DayCount -le $MinimumCertAgeDays) -and ($DayCount -gt 0)) { $certstatus = "Expiring" }
	Else { $certstatus = "Valid" }
		
	$Results = New-Object Object
	$Results | Add-Member -Type NoteProperty -Name 'URL' -Value $url
	$Results | Add-Member -Type NoteProperty -Name 'ExpirationDate' -Value $ExpirationDate
	$Results | Add-Member -Type NoteProperty -Name 'CertStatus' -Value $certstatus
	$Results | Add-Member -Type NoteProperty -Name 'Exp in Days' -Value $DayCount
	$Results | Add-Member -Type NoteProperty -Name 'Cert Issuer' -Value $certissuer
	$Results | Add-Member -Type NoteProperty -Name 'Responsible Team' -Value $urlin.Owner
		
	$props += $Results
}

Write-Output $props

$expiredcert = @()
Foreach ($ur in $props) {
	if ($ur.CertStatus -eq "Expired") {
		$expiredcert += $ur
	}	
}

$expiringcert = @()
Foreach ($ur1 in $props) {
	if (($ur1.'Expiring in Days' -le $MinimumCertAgeDays) -and ($ur1.CertStatus -like "Expiring")) {
		$expiringcert += $ur1
	}	
}

$Validcert = @()
Foreach ($ur in $props) {
	if ($ur.CertStatus -eq "Valid") {
		$Validcert += $ur
	}	
}


#region HTML BODY List
$Date = Get-Date -Format "MMM-dd-yyyy"
$htmloutput = ($SCRIPT_PARENT + "\certcheck.html")

New-HTML {
	New-HTMLSection -HeaderTextSize 12 -HeaderText "Data collected $(Get-date)" -HeaderTextAlignment left -BackgroundColor White -HeaderTextColor Black -HeaderBackGroundColor White { } #-MenuColor Black -MenuColorBackground Pink -HomeColorBackground Black -HomeColor Red
		
	New-HTMLSection -CanCollapse -Invisible {
		New-HTMLPanel -BackgroundColor LightBlue -AlignContentText right -BorderRadius 10px {
			New-HTMLText -TextBlock {
				# New-HTMLText -Text $UserDisabled -Alignment justify -FontSize 25 -FontWeight bold
				New-HTMLText -Text 'Total Sites' -Alignment justify -FontSize 15
				New-HTMLText -Text $props.count -Alignment justify -FontSize 25 -FontWeight bold
				New-HTMLTag -Tag 'i' -Attributes @{ class = "fas fa-laptop fa-2x" }
			}
		}



		New-HTMLPanel -BackgroundColor LightPink -AlignContentText right -BorderRadius 10px {
			New-HTMLText -TextBlock {
				# New-HTMLText -Text $UserDisabled -Alignment justify -FontSize 25 -FontWeight bold
				New-HTMLText -Text 'Certs Expired' -Alignment justify -FontSize 15
				New-HTMLText -Text $expiredcert.count -Alignment justify -FontSize 25 -FontWeight bold
				New-HTMLTag -Tag 'i' -Attributes @{ class = "fas fa-laptop fa-2x" }
			}
		}
		
		New-HTMLPanel -BackgroundColor Amber -AlignContentText right -BorderRadius 10px {
			New-HTMLText -TextBlock {
				# New-HTMLText -Text $UserDisabled -Alignment justify -FontSize 25 -FontWeight bold
				New-HTMLText -Text 'Certs Expiring' -Alignment justify -FontSize 15
				New-HTMLText -Text $expiringcert.count -Alignment justify -FontSize 25 -FontWeight bold
				New-HTMLTag -Tag 'i' -Attributes @{ class = "fas fa-laptop fa-2x" }
			}
		}

		New-HTMLPanel -BackgroundColor lightgreen -AlignContentText right -BorderRadius 10px {
			New-HTMLText -TextBlock {
				# New-HTMLText -Text $UserDisabled -Alignment justify -FontSize 25 -FontWeight bold
				New-HTMLText -Text 'Valid Certs' -Alignment justify -FontSize 15
				New-HTMLText -Text $Validcert.count -Alignment justify -FontSize 25 -FontWeight bold
				New-HTMLTag -Tag 'i' -Attributes @{ class = "fas fa-laptop fa-2x" }
			}
		}
	}
	
	New-HTMLSection -CanCollapse {
		New-HTMLTableStyle -BackgroundColor LightBlue -Type Header -FontSize 14 -TextAlign center
		New-HTMLTableStyle -BackgroundColor LightBlue -Type Footer -FontSize 14 
		New-HTMLTableStyle -Type RowOdd -FontSize 12 
		New-HTMLTableStyle -Type RowEven -FontSize 12
		New-HTMLTable -DataTable $props -DataTableID "CertTable" -DefaultSortColumn 'CertStatus' -SearchPane -SearchPaneLocation bottom -SearchRegularExpression -OrderMulti -Filtering {
			New-HTMLTableCondition -ComparisonType string -Name 'CertStatus' -Operator eq -Value 'Expired' -BackgroundColor LightPink -Color Black -Inline  -Alignment center
			New-HTMLTableCondition -ComparisonType string -Name 'CertStatus' -Operator eq -Value 'Expiring' -BackgroundColor Amber -Color Black -Inline  -Alignment center
			New-HTMLTableCondition -ComparisonType string -Name 'CertStatus' -Operator eq -Value 'Valid' -BackgroundColor lightgreen -Color Black -Inline  -Alignment center
		}
	}
	
} -FilePath $htmloutput -Format #-ShowHTML #-Online  #-ShowHTML

Copy-Item $htmloutput "P:\Script\CertCheck\Home.html" -Force 
#endregion 

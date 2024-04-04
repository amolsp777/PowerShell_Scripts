
<#	
	.NOTES
	===========================================================================
	 Created on:   	3/4/2024 11:30 AM
	 Created by:   	Amol Patil
	 Contact at:   	amolsp777@live.com
	 Contact at:   	https://github.com/amolsp777
	 Filename:     	Dell_deviceFirmware_v2.ps1
	===========================================================================
	.DESCRIPTION
		A description of the file.
#>

Import-Module DellOpenManage
Import-Module PSWriteHTML 

#region Connect OME server
$credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "fgdfg", $(ConvertTo-SecureString -Force -AsPlainText "!")
Connect-OMEServer -Name "dfgdfg" -Credentials $credentials -IgnoreCertificateWarning
#endregion

# Create an array to store objects
$objectsArray = @()

$getfirmwareinfo = Get-OMEFirmwareBaseline | Get-OMEFirmwareCompliance -UpdateAction All #| select * -First 1

Foreach ($ddevice in $getfirmwareinfo) {
	
    $Outobject = [PSCustomObject]@{
        "Device Name"       = $ddevice.DeviceName
        "Device Model"      = $ddevice.DeviceModel
        "ServiceTag"        = $ddevice.ServiceTag
        "Component"         = $ddevice.Name
        "Current Version"   = $ddevice.CurrentVersion
        "Baseline Version"  = $ddevice.Version
        "Compliance Status" = $ddevice.ComplianceStatus
        "Reboot Required"   = $ddevice.RebootRequired
        "Criticality"       = $ddevice.Criticality
        "Uri"               = $ddevice.Uri
    }
    # Add the custom object to the array
    $objectsArray += $Outobject
	
}

#-------------------------------------------------------------------@
# 			Filter criteria
#-------------------------------------------------------------------@
#region Filter criteria

$BIOSlist = $objectsArray | Where-Object { $_.Component -like "*BIOS*" }
$iDRAClist = $objectsArray | Where-Object { $_.Component -like "*idrac*" }

#region Get-GroupedDataWithTotalSum
function Get-GroupedDataWithTotalSum
{
    <#
    .SYNOPSIS
    Groups the input data based on a specified property and calculates the total count for each group.
    
    .DESCRIPTION
    This function takes an array of objects and groups them based on a specified property. It then calculates the total count for each group and appends a summary row at the end containing the total count of all groups, depending on the IncludeTotalSum switch parameter.
    
    .PARAMETER Data
    Specifies an array of objects representing the data that needs to be grouped.
    
    .PARAMETER GroupProperty
    Specifies the property based on which the grouping will be performed.
    
    .PARAMETER IncludeTotalSum
    Switch parameter to specify whether to include the total sum in the output. If specified, the summary row with the total sum will be included; otherwise, it will be excluded.
    
    .EXAMPLE
    $Data = Get-Content -Path "Data.txt"
    $GroupedData = $Data | Get-GroupedDataWithTotalSum -GroupProperty "Model" -IncludeTotalSum
    $GroupedData
    #>
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[array]$InputData,
		[Parameter(Mandatory = $true)]
		[string]$GroupProperty,
		[switch]$IncludeTotalSum
	)
	
	process
	{
		# Step 1: Grouping
		$GroupedData = $InputData | Group-Object -Property $GroupProperty |
		Select-Object @{
			Label	   = "Name"
			Expression = {
				if ($_.Name) { $_.Name }
				else { "[No Type]" }
			}
		}, @{
			N = "Total Count"
			E = { $_.Count }
		} | Sort-Object 'Total Count' -Descending
		
		# Step 2: Calculation of Total Count
		$TotalSum = ($GroupedData | Measure-Object -Property "Total Count" -Sum).Sum
		
		if ($IncludeTotalSum)
		{
			# Step 3: Creation of Summary Row
			$GroupedData += [PSCustomObject]@{
				Name		  = "Total Sum"
				"Total Count" = $TotalSum
			}
		}
		
		# Step 4: Output
		return $GroupedData
	}
}
#endregion Get-GroupedDataWithTotalSum

#$componentsType = Get-GroupedDataWithTotalSum -InputData $objectsArray -GroupProperty Component

$TotalDevices = Get-OMEDevice #| Format-Table

$ModelType = Get-GroupedDataWithTotalSum -InputData $TotalDevices -GroupProperty model

$BIOSChart = Get-GroupedDataWithTotalSum -InputData $BIOSlist -GroupProperty "Compliance Status" | Sort-Object "name"

$iDRACChart = Get-GroupedDataWithTotalSum -InputData $iDRAClist -GroupProperty "Compliance Status" | Sort-Object "name"

$allChart = Get-GroupedDataWithTotalSum -InputData $objectsArray -GroupProperty "Compliance Status" | Sort-Object "name"

#endregion Filter criteria


#-------------------------------------------------------------------*
#  HTML Page with Dashboard creation
#-------------------------------------------------------------------*
#region HTML Page with Dashboard creation 
$finalHTML = ($PSScriptRoot + '\DellFirmware_Report.html')

#region Generate HTML Page - PSWriteHTML Module
New-HTML {
    New-HTMLSection -HeaderTextSize 12 -HeaderText "Data collected $(Get-date)" -HeaderTextAlignment left -BackgroundColor White -HeaderTextColor Black -HeaderBackGroundColor White { } #-MenuColor Black -MenuColorBackground Pink -HomeColorBackground Black -HomeColor Red
	
    New-HTMLSection -CanCollapse {
        New-HTMLPanel -BackgroundColor White {
            New-HTMLText -TextBlock {
                New-HTMLText -Text 'Total Devices' -Alignment justify -FontSize 15
                New-HTMLText -Text $TotalDevices.count -Alignment justify -FontSize 25 -FontWeight bold
                New-HTMLTag -Tag 'i' -Attributes @{ class = "fas fa-laptop fa-2x" }
            }
            New-HTMLTable -DataTable $ModelType -Buttons csvHtml5, copyHtml5 -HideFooter -DisablePaging -DisableSearch
			
        }
		
        New-HTMLPanel -Invisible {			
            $Data1 = @($BIOSChart.'Total Count')
            $DataNames1 = @($BIOSChart.Name)
            New-HTMLChart -Title "BIOS" -TitleAlignment center -Height 300 -Width 300 {
                #New-ChartLegend -Color Green, BrinkPink  -LegendPosition bottom
                New-ChartLegend -Color BrinkPink, Green, Amber -LegendPosition bottom
                for ($i = 0; $i -lt $Data1.Count; $i++) {
                    New-ChartPie -Name $DataNames1[$i] -Value $Data1[$i]
                    New-ChartEvent -DataTableID 'BIOS' -ColumnID 0
                }
            }
            New-HTMLTable -DataTable $BIOSChart -DataTableID 'BIOS' -HideButtons -HideFooter -DisablePaging
        }
        New-HTMLPanel -Invisible {
			
            $Data1 = @($iDRACChart.'Total Count')
            $DataNames1 = @($iDRACChart.Name)
            New-HTMLChart -Title "iDRAC" -TitleAlignment center -Height 300 -Width 300 {
                New-ChartLegend -Color BrinkPink, Green, Amber -LegendPosition bottom
                for ($i = 0; $i -lt $Data1.Count; $i++) {
                    New-ChartPie -Name $DataNames1[$i] -Value $Data1[$i]
                    New-ChartEvent -DataTableID 'iDRAC' -ColumnID 0
                }
            }
            New-HTMLTable -DataTable $iDRACChart -DataTableID 'iDRAC' -HideButtons -HideFooter -DisablePaging
        }
        New-HTMLPanel -Invisible {
            $Data1 = @($allChart.'Total Count')
            $DataNames1 = @($allChart.Name)
            New-HTMLChart -Title "All Compliance Status" -TitleAlignment center -Height 300 -Width 300 {
                New-ChartLegend -Color BrinkPink, Green, Amber -LegendPosition bottom
                for ($i = 0; $i -lt $Data1.Count; $i++) {
                    New-ChartPie -Name $DataNames1[$i] -Value $Data1[$i]
                    New-ChartEvent -DataTableID 'allChart' -ColumnID 0
                }
            }
            New-HTMLTable -DataTable $allChart -DataTableID 'allChart' -HideButtons -HideFooter -DisablePaging
        }
    }
	
    New-HTMLSection -HeaderBackGroundColor BrickRed -HeaderTextSize 16 -Margin 10 -HeaderText 'Critical' {
        New-HTMLSection -HeaderTextSize 16 -HeaderTextColor Black -Title 'BIOS' {
            New-htmlTable -DataTable $BIOSlist -TextWhenNoData 'NO Data' -PagingOptions 5, 15, 50 {
				
                New-HTMLTableCondition -name 'Compliance Status' -ComparisonType string -Operator eq -Value 'CRITICAL' -BackgroundColor BrinkPink -FontFamily verdana
                New-HTMLTableCondition -name 'Compliance Status' -ComparisonType string -Operator eq -Value 'WARNING' -BackgroundColor Amber -FontFamily verdana
                New-HTMLTableCondition -name 'Compliance Status' -ComparisonType string -Operator eq -Value 'OK' -BackgroundColor CaribbeanGreen -FontFamily verdana
				
            } -Filtering
        }
		
    }
    New-HTMLSection -HeaderBackGroundColor BrickRed -HeaderTextSize 16 -Margin 10 -HeaderText 'Critical' -Invisible {
		
        New-HTMLSection -HeaderTextSize 16 -HeaderTextColor Black -Title 'iDRAC' {
            New-htmlTable -DataTable $iDRAClist -TextWhenNoData 'NO Data' -PagingOptions 5, 15, 50 {
				
                New-HTMLTableCondition -name 'Compliance Status' -ComparisonType string -Operator eq -Value 'CRITICAL' -BackgroundColor BrinkPink -FontFamily verdana
                New-HTMLTableCondition -name 'Compliance Status' -ComparisonType string -Operator eq -Value 'WARNING' -BackgroundColor Amber -FontFamily verdana
                New-HTMLTableCondition -name 'Compliance Status' -ComparisonType string -Operator eq -Value 'OK' -BackgroundColor CaribbeanGreen -FontFamily verdana
            } -Filtering
        }
		
    }
	
    New-HTMLSection -HeaderTextSize 16 -HeaderTextColor Black {
		
        New-htmlTable -DataTable $objectsArray -TextWhenNoData 'NO data ' {
            #New-HTMLTableCondition -name 'Reboot Date/Time' -ComparisonType date -Operator le -Value $24hrs -BackgroundColor Amber -FontFamily verdana
            New-HTMLTableCondition -name 'Compliance Status' -ComparisonType string -Operator eq -Value 'CRITICAL' -BackgroundColor BrinkPink -FontFamily verdana
            New-HTMLTableCondition -name 'Compliance Status' -ComparisonType string -Operator eq -Value 'WARNING' -BackgroundColor Amber -FontFamily verdana
            New-HTMLTableCondition -name 'Compliance Status' -ComparisonType string -Operator eq -Value 'OK' -BackgroundColor CaribbeanGreen -FontFamily verdana
        } -PagingLength 5 -SearchPane -SearchPaneLocation bottom -Filtering
    } -HeaderText 'All Device compliance'
	
} -FilePath $finalHTML -Format #-Online  #-ShowHTML

#endregion Generate HTML Page - PSWriteHTML Module
#endregion HTML Page with Dashboard creation 

# Copy that HTML file somewhere
Copy-Item $finalHTML "C:\DellOME\Home.html" -Force

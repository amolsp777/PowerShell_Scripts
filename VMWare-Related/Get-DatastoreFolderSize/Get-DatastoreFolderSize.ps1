Connect-VIServer -Server "vcname"

function Get-DatastoreFolderSize {
        <#
.NOTES
===========================================================================
Created by: Ankush Sethi
Blog:       www.vmwarecode.com
===========================================================================
.SYNOPSIS
Provide the VMFolder Size Utilization
.DESCRIPTION
Function will provide the vmfolder size in datastore using PowerCli
.PARAMETER Datastore
Enter the Datastore name for which you want to check the utilization
.PARAMETER ExportToCSV
If you want to genetate the report
 
.EXAMPLE
 Get-DatastoreFolderSize -Datastore (Get-Datastore DSname) 
 Get-Datastore SA-shared-01-ms-remote|Get-DatastoreFolderSize
 Get-Datastore SA-shared-01-ms-remote|Get-DatastoreFolderSize -ExportToCSV:$true
#>
 
        param(
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.DatastoreImpl]
                $Datastore,
                [switch]$ExportToCSV
        )
        Begin {
                Write-Host "Getting the space details" -ForegroundColor Yellow
                $DSobject = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
                $DSfileobject = New-Object VMware.Vim.FileQueryFlags
                $DSfileobject.Modification = $true
                $DSfileobject.FileSize = $true
                $DSfileobject.FileOwner = $true
                $DSfileobject.FileType = $true
                $DSobject.Details = $DSfileobject
        }
        Process {
                Try {
                        foreach ($as in $Datastore) {
                                $ds = Get-Datastore $as -ErrorAction Stop
                        }
                }
                catch {
                        Write-Error -Message "Entered datastore is not found" -ErrorAction Stop
                }
                foreach ($store in $Datastore) {
                        $dspath = "[" + $store.name + "]"
                        $dsview = Get-View -id $store.ExtensionData.browser
                        $output += @($dsview.SearchDatastoreSubFolders($dspath, $DSobject) | select Folderpath,
                                @{N = "FolderSize-MB"; E = { [math]::Round((($_.file | measure -Property Filesize -sum).sum) / 1MB, 2) } },
                                @{N = "FolderSpace-GB"; E = { [math]::Round((($_.file | measure -Property FileSize -Sum).sum) / 1GB, 2) } },
                                @{N = "TotalFiles"; E = { ($_.file | measure -Property FileSize).count } },
                                @{N = "Last-Modified"; E = { ($_.File | Sort-Object -Property Modification -Descending | select -First 1).modification } }
                        )
                }
        }
 
        End {
                Write-Host "------------------------------------------------------------------------------------------------------------------------------------------------"
                $output | FT -AutoSize | Out-Default
 
                Write-Host "------------------------------------------------------------------------------------------------------------------------------------------------"
                If ($ExportToCSV -eq $true) {
 
                        $path = Get-Location
                        $name = "\VMwareCode_VMfolderReport" + " " + ($global:DefaultVIServer).name.Split('.')[0] + ".csv"
                        $Reportname = $path.path + $name
                        $output | Export-Csv -NoTypeInformation -Path $Reportname
                }
 
        }
 
}
	
Get-DatastoreFolderSize -Datastore (Get-Datastore 'mydatastore') #| where {$_.FolderPath -like "*amol*"}

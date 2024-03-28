
# Header

#========================================================================
# Created BY:	AMOL PATIL
# Email     :   pscriptsasp@gmail.com
# Created ON:	7/28/2019 9:58 PM
# Updated ON:   
#========================================================================
<#
DESCRIPTION:
			This script will fetch the server information remotly.
			
REQUIREMENTS:	
			Powershell, WMI and access to the server.
            Make sure you are running this script with the account for which you have access to the target server. 
			
VERSION HISTORY:

0.2     :   New1
0.1     :   New
Date - 04/03/2023 

Adding CPU core count in this report.

#>

#========================================================================


# Used PSWriteHTML  0.0.71
# Used Dashimo 0.0.22

# Get Start Time | to get the total elepsed time to complete this script.
$startMain = (Get-Date)


#$servers = Get-Content S:\Get-ServerInventory\Servers.txt
#region Root directory to save outfile	 <3/8/2017>
$SCRIPT_PARENT = $PSScriptRoot
#endregion
#

#$date = $(Get-Date -Format "yyyy-MM-dd-HHmm")


#region Check if the Reports folder exists, and create it if not. And delete .HTML & .CSV files older than 60 days

$reportsFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "Reports"
if (-not (Test-Path -Path $reportsFolderPath -PathType Container)) {
	Write-Host "Reprots folder not found. Creating folder.." -ForegroundColor Yellow
	New-Item -Path $reportsFolderPath -ItemType Directory
}

# Get CSV and HTML files older than 60 days in the Reports folder
$oldFiles = Get-ChildItem -Path $reportsFolderPath | Where-Object { $_.Extension -eq '.csv' -or $_.Extension -eq '.html' -or $_.Extension -eq '.txt' -and $_.CreationTime -lt (Get-Date).AddDays(-60) }
$oldFiles.count

# Check if old files were found before attempting to delete them
if ($oldFiles.Count -gt 0) {
	# Delete the old CSV and HTML files
	foreach ($file in $oldFiles) {
		Remove-Item -Path $file.FullName -Force
	}
	Write-Verbose "$($oldFiles.Count) Old CSV and HTML files deleted."
}
else {
	Write-Host "No old CSV and HTML files found."
}

#endregion Check if the Reports folder exists, and create it if not. And delete .HTML & .CSV files older than 60 days 



$ErrorActionPreference = "SilentlyContinue"

Function Add-WriteHost {
	[CmdletBinding()]
	Param
	(
		[Parameter(Mandatory = $true,
			ValueFromPipeline = $true,
			ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[Alias("LogContent")]
		[string]$Message,
		[Parameter(Mandatory = $false)]
		[ValidateSet("Red", "Yellow", "Green")]
		[string]$Color = "White",
		[Parameter(Mandatory = $false)]
		[ValidateSet("Error", "Warn", "Info")]
		[string]$Level = "Info",
		[Parameter(Mandatory = $false)]
		[string]$LogFile # Added parameter for specifying the log file path
	)
	
	$FormattedDate = Get-Date -Format "[yyyy-MM-dd-HH:mm:ss]"
	$LevelText = $Level.ToUpper() + ':'
	
	$LogMessage = "$FormattedDate $LevelText $Message"
	
	if ($LogFile) {
		# Use the specified log file path and append data
		Add-Content -Path $LogFile -Value $LogMessage -Append
	}
	else {
		# Use the current working directory and create a log file with a timestamp
		$ScriptRoot = $PSScriptRoot
		if (-not $ScriptRoot) {
			$ScriptRoot = Get-Location
		}
		
		$LogFileName = Join-Path -Path $ScriptRoot -ChildPath "Log_$((Get-Date -Format 'yyyyMMdd').ToString()).log"
		Add-Content -Path $LogFileName -Value $LogMessage
	}
	
	switch ($Level) {
		'Error' {
			Write-Host $LogMessage -ForegroundColor Red
		}
		'Warn' {
			Write-Host $LogMessage -ForegroundColor Yellow
		}
		'Info' {
			Write-Host $LogMessage -ForegroundColor $Color
		}
	}
}


Add-WriteHost "[Start] Job Started" -Color Yellow

#region Script Path output  and Set the location on SystemDrive
# $Date = Get-Date -Format "MMM-dd-yyyy"
$ScriptPath = (Split-Path -Path ((Get-Variable -Name MyInvocation).Value).MyCommand.Path)
#$Mainpath = $ScriptPath #"E:\UserPassChng_Log"
#$ScriptName = (($MyInvocation.MyCommand.Name) -replace (".ps1", ""))


$sysDrive = $env:SystemDrive + "\"

$ScriptOutputPath = $sysDrive + "_Script-Output"
If (!(test-path $ScriptOutputPath)) { New-Item -ItemType Directory -Force -Path $ScriptOutputPath | Out-Null }
#Set-Location $ScriptOutputPath

#endregion

# $WSAServers = Get-ADGroupMember "Servers_list" 
# $ObjectCount = $WSAServers.count

# Get the Windows server list from the WSA-ALL-SERVERS group
$WSAServers = Get-ADComputer -filter {( name -like "*") -and ( OperatingSystem -like "*server*") } -Properties * #| select -First 20
Write-Host "Servers are in AD - " $WSAServers.count
$ObjectCount = $WSAServers.count


$CompS = $WSAServers.name #| select -First 5

$InventoryBlock = {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $false)]
		[string[]]$ComputerName #= $env:COMPUTERNAME  
	)
	
	
	# $ErrorActionPreference = "SilentlyContinue"
	
	#region Simple Add-WriteHost Function
	# It will write notmal time based logs on the screen
	
	$i++
	
	$logpath = $("\\asdwsa002\p$\_Scripts\Server-Status-Report\Reports\Log_$((Get-Date -Format 'yyyyMMdd').ToString()).log")
	#$logpath = ($reportsFolderPath + "\_Log_$((Get-Date -Format 'yyyyMMdd').ToString()).log")
	Function Add-WriteHost {
		[CmdletBinding()]
		Param
		(
			[Parameter(Mandatory = $true,
				ValueFromPipeline = $true,
				ValueFromPipelineByPropertyName = $true)]
			[ValidateNotNullOrEmpty()]
			[Alias("LogContent")]
			[string]$Message,
			[Parameter(Mandatory = $false)]
			[ValidateSet("Red", "Yellow", "Green")]
			[string]$Color = "White",
			[Parameter(Mandatory = $false)]
			[ValidateSet("Error", "Warn", "Info")]
			[string]$Level = "Info",
			[Parameter(Mandatory = $false)]
			[string]$LogFile = $logpath #"\\files.lanvera.org\Old-Data\LV2PFS02\Users\ep.ap0926" + "\Log_$((Get-Date -Format 'yyyyMMdd').ToString()).log" # Added parameter for specifying the log file path
		)
		
		Begin {
			if ($LogFile) {
				$LogFileName = $LogFile
			}
			else {
				$ScriptRoot = $PSScriptRoot
				if (-not $ScriptRoot) {
					$ScriptRoot = Get-Location
				}
				$LogFileName = Join-Path -Path $ScriptRoot -ChildPath "Log_$((Get-Date -Format 'yyyyMMddHHmmss').ToString()).log"
			}
		}
		
		Process {
			# Convert the input message to a string using Out-String
			$Message = ($Message | Out-String).Trim()
			
			$FormattedDate = Get-Date -Format "[yyyy-MM-dd-HH:mm:ss]"
			$LevelText = $Level.ToUpper() + ':'
			$LogMessage = "$FormattedDate $LevelText $Message"
			
			# Append the formatted message to the log file using Out-File with -Append
			$LogMessage | Out-File -Append -FilePath $LogFileName
			
			switch ($Level) {
				'Error' {
					Write-Host $LogMessage -ForegroundColor Red
				}
				'Warn' {
					Write-Host $LogMessage -ForegroundColor Yellow
				}
				'Info' {
					Write-Host $LogMessage -ForegroundColor $Color
				}
			}
		}
		
		End {
			# If you want to return the log file path at the end
			# return $LogFileName
		}
	}
	
	
	#endregion 
	#Add-WriteHost "[$ADcompName]-----------------S>"
	$ADcompName = "$($ComputerName)"
	
	Import-Module ActiveDirectory
	
	
	
	$infoColl = @()
	
	Function GetStatusCode {
		Param ([int]$StatusCode)
		switch ($StatusCode) {
			#0 	{"Online"}
			11001 { "Buffer Too Small" }
			11002 { "Destination Net Unreachable" }
			11003 { "Destination Host Unreachable" }
			11004 { "Destination Protocol Unreachable" }
			11005 { "Destination Port Unreachable" }
			11006 { "No Resources" }
			11007 { "Bad Option" }
			11008 { "Hardware Error" }
			11009 { "Packet Too Big" }
			11010 { "Request Timed Out" }
			11011 { "Bad Request" }
			11012 { "Bad Route" }
			11013 { "TimeToLive Expired Transit" }
			11014 { "TimeToLive Expired Reassembly" }
			11015 { "Parameter Problem" }
			11016 { "Source Quench" }
			11017 { "Option Too Big" }
			11018 { "Bad Destination" }
			11032 { "Negotiating IPSEC" }
			11050 { "General Failure" }
			default { "Failed" }
		}
	}
	
	$pingStatus = Test-Connection $ComputerName -Count 1 -ErrorAction SilentlyContinue #| select ResponseTimeToLive,IPV4Address,StatusCode
	$TTLOS = $pingStatus.ResponseTimeToLive
	
	
	#region 	FQDN CHECK	 <3/23/2017>
	$Uptime = $null
	#$Resolve = [System.Net.Dns]::Resolve($ServerName) 
	try { $Resolve = [System.Net.Dns]::GetHostEntry($ComputerName) }
	
	catch { $Resolve = $null }
	
	if ($pingStatus.StatusCode -eq 0) {
		$PingCode = "Online"
		#do-Log -Message "[OK]-[$sysname] TTL is - $($TTLOS)."
		#$FQDN = $FQDN1
	}
	
	Else { $PingCode = GetStatusCode($pingStatus.StatusCode) }
	
	If ($pingStatus.PrimaryAddressResolutionStatus -eq 0)
	{ $FQDN = [string]$Resolve.HostName }
	
	Else { $FQDN = "Not Responding" }
	
	#endregion
	
	$sysname = "$($computername)"
	
	$DataUpdateTime = Get-Date -Format "MM/dd/yyyy HH:mm"
	
	If (($pingStatus.StatusCode -eq 0) -and ($TTLOS -ge 100 -and $TTLOS -le 128 -or $TTLOS -le 0)) {
		#Add-WriteHost "[$ADcompName]- Checking OS & Hotfix Details"
		$CPUInfoCount = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ComputerName
		If (($CPUInfoCount.Manufacturer -like "VM*") -or ($CPUInfoCount.Manufacturer -like "Microsoft*")) {
			$phyvm = "Virtual"
		}
		else { $phyvm = "Physical" }
		
		
		#region Check Host Uptime 
		Function Get-HostUptime {
			param ([string]$ComputerName)
			$Uptime = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName
			$LastBootUpTime = $Uptime.ConvertToDateTime($Uptime.LastBootUpTime)
			$Time = (Get-Date) - $LastBootUpTime
			#Return '{0:00} Days, {1:00} Hours' -f $Time.Days, $Time.Hours #, $Time.Minutes, $Time.Seconds
			Return '{0:00}' -f $Time.Days #, $Time.Hours, $Time.Minutes, $Time.Seconds
		}
		
		$Uptime = Get-HostUptime -ComputerName $ComputerName
		#endregion
		
		$OSInfo = Get-WmiObject win32_operatingsystem -ComputerName $ComputerName
		
		$cpus = (Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $ComputerName) #.NumberOfLogicalProcessors
		
		# $diskVol = Invoke-Command $ComputerName { Get-Volume | sort FileSystemLabel | Out-String }
		
		#region Get last 3 Hotfix details
		#$Hotfix3 = Get-HotFix -ComputerName $ComputerName | select -Last 1
		$Hotfix3 = Get-HotFix -ComputerName $sysname | Sort-Object InstalledOn -Descending | Select-Object -First 1 #Get-HotFix -ComputerName $sysname | sort InstalledOn -Descending | select -First 1
		$hotfixID = $Hotfix3.hotfixid -join "`n"
		$hotfixInstalledON = $Hotfix3.InstalledOn -join "`n"
		$hotfixInstalledBy = $Hotfix3.InstalledBy -join "`n"
		#endregion
		
		
		#region C Disk details.
		#Add-WriteHost "[$ADcompName]- Checking Disk Details"
		$DiskInfo = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $ComputerName | Where-Object { $_.DeviceID -like "C:" } |
		Select-Object -Property DeviceID, VolumeName, @{ Label = 'FreeSpace (Gb)'; expression = { ($_.FreeSpace / 1GB).ToString('F2') } },
		@{ Label = 'Total (Gb)'; expression = { ($_.Size / 1GB).ToString('F2') } },
		@{ label = 'FreePercent'; expression = { [Math]::Round(($_.freespace / $_.size) * 100, 0) } }
		
		#endregion
		
		
		
		#region Ad info
		#$ADComp = Get-ADComputer -Filter {Name -eq $ComputerName} -Properties  Name,Enabled,OperatingSystem,OperatingSystemVersion,IPv4Address,LastLogonDate,DistinguishedName,MemberOf,whenChanged | Select-Object Name,Enabled,OperatingSystem,OperatingSystemVersion,IPv4Address,LastLogonDate,DistinguishedName,whenChanged,@{n="MemberOfGroup";e={($_.MemberOf -like '*patch*') -replace "(CN=)(.*?),.*",'$2' -join "`n" }},@{n="MemberOf-Count";e={($_.MemberOf -like '*patch*').count}} -Verbose
		$ADComp = Get-ADComputer $ADcompName -Properties Name, Enabled, OperatingSystem, OperatingSystemVersion, IPv4Address, LastLogonDate, DistinguishedName, MemberOf, whenCreated, whenChanged | Select-Object Name, Enabled, OperatingSystem, OperatingSystemVersion, IPv4Address, LastLogonDate, DistinguishedName, whenCreated, whenChanged, @{ n = "MemberOfGroup"; e = { ($_.MemberOf -like '*patch*') -replace "(CN=)(.*?),.*", '$2' -join "`n" } }, @{ n = "MemberOf-Count"; e = { ($_.MemberOf -like '*patch*').count } }
		$patchgroup = $ADComp | Select-Object @{ n = "Group1"; e = { [string]$_.MemberOfGroup.Split("`r`n")[0] } }, @{ n = "Group2"; e = [string] { $_.MemberOfGroup.Split("`r`n")[1] } }, @{ n = "Group3"; e = { [string]$_.MemberOfGroup.Split("`r`n")[2] } }, @{ n = "Group4"; e = [string] { $_.MemberOfGroup.Split("`r`n")[3] } } #| select -First 5
		#endregion
		
		#region Check ManageEngine UEMS - Agent
		#Add-WriteHost "[$ADcompName]- Checking Services"
		try {
			$ManageEngineService = Get-Service -ComputerName $computername -Name 'ManageEngine UEMS - Agent' # | select Status
			If ($ManageEngineService -ne $null) {
				If (($ManageEngineService.Status -eq "Running")) {
					$ManageEngineStatus = "ManageEngine-Running"
				}
				Elseif (($ManageEngineService.Status -ne "Running")) {
					$ManageEngineStatus = "ManageEngine-Not Running"
				}
				
			}
			Else {
				$ManageEngineStatus = "ManageEngine not found"
			}
		}
		
		catch {
			$ManageEngineStatus = "Unable to access"
		}
		#endregion
		
		#Foreach ($CPU in $CPUInfo)
		#{
		$infoObject = New-Object PSObject
		#The following add data to the infoObjects.	
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "ServerName" -value $sysname
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'FQDN' -Value $FQDN
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'Status' -Value $PingCode
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'IPV4Address' -Value $pingStatus.IPV4Address
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'TTL' -Value $TTLOS
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'Phy_VM' -Value $phyvm
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'Uptime' -Value $($Uptime)
		
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'Hotfix ID' -Value $hotfixID
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'Hotfix Intalled ON' -Value $hotfixInstalledON
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'Hotfix Intalled By' -Value $hotfixInstalledBy
		
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'C-Disk-FreeSpace' -Value $DiskInfo.'FreeSpace (Gb)'
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'C-Disk-Free %' -Value $DiskInfo.FreePercent
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'C-Disk-Capacity' -Value $DiskInfo.'Total (Gb)'
		
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'Processors' -Value $cpus.NumberOfProcessors
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'LogicalProcessors' -Value $cpus.NumberOfLogicalProcessors
		
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "OS_Name" -value $OSInfo.Caption
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "OS_Version" -value $OSInfo.Version
		
		
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'ManageEngine' -Value $ManageEngineStatus
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'Enabled' -Value $ADComp.Enabled
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'OperatingSystem' -Value $ADComp.OperatingSystem
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'OperatingSystemVersion' -Value $ADComp.OperatingSystemVersion
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'AD-IPv4Address' -Value $ADComp.IPv4Address
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'LastLogonDate' -Value $ADComp.LastLogonDate
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'DistinguishedName' -Value $ADComp.DistinguishedName
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'whenCreated' -Value $ADComp.whenCreated
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'whenChanged' -Value $ADComp.whenChanged
		
		# Add-Member -inputObject $infoObject -memberType NoteProperty -name "Disk & Volumes" -value $diskVol
		
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'MemberOf-PatchGrp-Count' -Value $ADComp.'MemberOf-Count'
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'PatchGroup 1' -Value $patchgroup.Group1
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'PatchGroup 2' -Value $patchgroup.Group2
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'PatchGroup 3' -Value $patchgroup.Group3
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'PatchGroup 4' -Value $patchgroup.Group4
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "DataUpdateTime" -value $DataUpdateTime
		#$infoObject #Output to the screen for a visual feedback.
		$infoColl += $infoObject
		#}
		#Add-WriteHost "[$ADcompName]-----Output-Loading-----"
		
	}
	
	
	else {
		Write-Host "Server not reachable - $($ComputerName)"
		#Add-WriteHost "[$ADcompName]- Server not reachable"
		$infoObject = New-Object PSObject
		#The following add data to the infoObjects.	
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "ServerName" -value $sysname
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'FQDN' -Value $FQDN
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'Status' -Value $PingCode
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'IPV4Address' -Value $pingStatus.IPV4Address
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'TTL' -Value $TTLOS
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'Phy_VM' -Value ""
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'Uptime' -Value ""
		
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'Hotfix ID' -Value ""
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'Hotfix Intalled ON' -Value ""
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'Hotfix Intalled By' -Value ""
		
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'Processors' -Value ""
		Add-Member -inputObject $infoObject -memberType NoteProperty -name 'LogicalProcessors' -Value ""
		
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "OS_Name" -value ""
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "OS_Version" -value ""
		
		
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'ManageEngine' -Value ""
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'Enabled' -Value ""
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'OperatingSystem' -Value ""
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'OperatingSystemVersion' -Value ""
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'AD-IPv4Address' -Value ""
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'LastLogonDate' -Value ""
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'DistinguishedName' -Value ""
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'whenCreated' -Value $ADComp.whenCreated
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'whenChanged' -Value ""
		
		# Add-Member -inputObject $infoObject -memberType NoteProperty -name "Disk & Volumes" -value ""
		
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'MemberOf-PatchGrp-Count' -Value ""
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'PatchGroup 1' -Value ""
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'PatchGroup 2' -Value ""
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'PatchGroup 3' -Value ""
		Add-Member -inputObject $infoObject -memberType NoteProperty -Name 'PatchGroup 4' -Value ""
		Add-Member -inputObject $infoObject -memberType NoteProperty -name "DataUpdateTime" -value $DataUpdateTime
		#$infoObject #Output to the screen for a visual feedback.
		$infoColl += $infoObject
	}
	$infoColl
}

Add-WriteHost "[Objects] Total Devices to check - $count"


$i = 0
foreach ($ComputerName in $CompS) {
	$i++
	Write-Progress -Activity "Running Jobs.." -Status " $i/$($CompS.count)  $ComputerName" -PercentComplete $(Try { $i / ($CompS.count) * 100 }
		Catch { 0 })
	
	$MaxThreads = 50
	While (@(Get-Job | Where-Object { $_.State -eq "Running" }).Count -ge $MaxThreads) {
		Write-Host "Waiting for open thread...($MaxThreads Maximum)"
		Start-Sleep -Seconds 3
	}
	
	Start-Job -Name "S-$ComputerName" -InputObject $ComputerName -ScriptBlock $InventoryBlock -ArgumentList $ComputerName -ErrorAction SilentlyContinue
	
	# $JobsStatus = (Get-Job -Name "Srv*" | Where-Object { $_.State -in @("Completed", "Failed").count })
}

While (@(Get-Job | Where-Object { $_.State -eq "Running" }).Count -ne 0) {
	Write-Host "Waiting for background jobs..."
	Get-Job | Where-Object { $_.State -ne "Completed" } #Just showing all the jobs # 
	Start-Sleep -Seconds 5
	# Get-Job | Wait-Job -Timeout 10 
	$timeout = [timespan]::FromMinutes(10)
	$now = Get-Date
	Write-Host "Job running for longer time..going to Stop" -ForegroundColor Red
	Get-Job | Where-Object {
		$_.State -eq 'Running' -and
		(($now - $_.PSBeginTime) -gt $timeout)
	} | Stop-Job
}

Write-host "Processing for Output...." -BackgroundColor Yellow

$TotalJobs = Get-Job

#region Job Status Count
$TotalJobsCount = $TotalJobs | Select-Object State | Group-Object State | Select-Object @{
	Label      = "Job Status"
	Expression = { if ($_.Name) { $_.Name }
		else { "[No Type]" } }
}, @{ N = "Total Count"; E = { $_.count } } | Sort-Object 'Total Count' -Descending

#endregion

# Get-Job       #Just showing all the jobs
$Data = ForEach ($Job in (Get-Job)) {
	Receive-Job $Job
	Remove-Job $Job
}

$TotalJobsCount | Format-Table -AutoSize -Wrap -Property *

#region Get the JOB status summary and Update Job status in Text file
$(Get-Date) | Out-File ($reportsFolderPath + "\JobStatus_$((Get-Date).ToString('MM-dd-yyyy')).txt") -Append
$TotalJobsCount | Out-File ($reportsFolderPath + "\JobStatus_$((Get-Date).ToString('MM-dd-yyyy')).txt") -Append

If ($TotalJobs.State -eq 'Failed') {
	
	$TotalJobs | Where-Object { $_.State -eq 'Failed' } | Select-Object State, Name | Out-File ($SCRIPT_PARENT + "\JobStatus_$((Get-Date).ToString('MM-dd-yyyy')).txt") -Append
}
#endregion

$outputCSV = ($reportsFolderPath + "\JOBs-Server_Inventory_$((Get-Date).ToString('MM-dd-yyyy')).csv")

#------ Ope below comment if you need to view output in Command Output

$Data | Select-Object * -ExcludeProperty RunspaceId, PSComputerName, PSShowComputerName | Export-Csv -path $outputCSV -NoTypeInformation

Add-WriteHost "Output file saved at path - $ScriptPath"

$importCSVData = Import-Csv $outputCSV
$outputfileHTML = ($reportsFolderPath + "\Server_UPTime_$((Get-Date).ToString('MM-dd-yyyy')).html")

#region HTML Dashboard

#region Data collection for Dashboard

#region UP time 40+ days  # ($importCSVData | where{$_.uptime.trim("Days") -ge "27" })
$Uptime40UP_List = $importCSVData | Where-Object { ($_.uptime -ge "40") } | Select-Object ServerName, FQDN, Status, Uptime, 'Hotfix ID', 'Hotfix Intalled ON', 'Hotfix Intalled By', OS_Name, 'ManageEngine', Phy_VM, PatchGroup* | Sort-Object uptime -Descending
#$Uptime_List = $importCSVData | select ServerName, FQDN, Status, Uptime, 'Hotfix ID', 'Hotfix Intalled ON', 'Hotfix Intalled By', OS_Name, 'ManageEngine', Phy_VM, PatchGroup* | sort uptime -Descending
#endregion

#region UP time 40+ days  # ($importCSVData | where{$_.uptime.trim("Days") -ge "27" })
$CDiskAlert_List = $importCSVData | Where-Object { (($_.'C-Disk-Free %' -ne "$null") -and ($_.'C-Disk-Free %' -le "12")) } | Select-Object * -ExcludeProperty RunspaceId, PSComputerName, PSShowComputerName | Sort-Object 'C-Disk-FreeSpace' -Descending
#endregion

#region not patch last 30 days
# $Uptime40UP_List = $importCSVData | where{($_.uptime.trim("Days") -ge "40") | sort uptime  } 
$less30days = ((Get-Date).AddDays(-30))
$30DaysHotfixAlert_List = $importCSVData | Where-Object { ($_.'Hotfix Intalled ON' -gt "$less30days") } | Select-Object * -ExcludeProperty RunspaceId, PSComputerName, PSShowComputerName | Sort-Object 'Hotfix Intalled ON' -Descending
#endregion


#region OS Counts
$OS_Counts_All = $importCSVData | Where-Object { $_.OS_Name -like "*" } | Group-Object OS_Name | Select-Object @{
	Label      = "Name"
	Expression = { if ($_.Name) { $_.Name -replace "Microsoft Windows Server ", "" }
		else { "[No Type]" } }
}, @{ N = "Total Count"; E = { $_.count } } | Sort-Object 'Total Count' -Descending
#endregion


#region OS Counts ONLINE
$OS_Counts_Online = $importCSVData | Where-Object { ($_.OS_Name -like "*") -and ($_.status -ne "Failed") } | Group-Object OS_Name | Select-Object @{
	Label      = "Name"
	Expression = { if ($_.Name) { $_.Name -replace "Microsoft Windows Server ", "" }
		else { "[No Type]" } }
}, @{ N = "Total Count"; E = { $_.count } } | Sort-Object 'Total Count' -Descending
#endregion

#region OS Counts NOT ONLINE
$OS_Counts_NotOnline = $importCSVData | Where-Object { ($_.OS_Name -like "*") -and ($_.status -ne "Online") } | Group-Object OS_Name | Select-Object @{
	Label      = "Name"
	Expression = { if ($_.Name) { $_.Name -replace "Microsoft Windows Server ", "" }
		else { "[No Type]" } }
}, @{ N = "Total Count"; E = { $_.count } } | Sort-Object 'Total Count' -Descending
#endregion

$BMCAgent_Counts = $importCSVData | Where-Object { $_.'ManageEngine' -like "*" } | Group-Object 'ManageEngine' | Select-Object @{
	Label      = "Name"
	Expression = { if ($_.Name) { $_.Name }
		else { "[No Type]" } }
}, @{ N = "Total Count"; E = { $_.count } } | Sort-Object 'Total Count' -Descending
#endregion

#region Server Type Counts Physical/Virtual
$SrvTypes_Counts = $importCSVData | Where-Object { $_.Phy_VM -like "*" } | Group-Object Phy_VM | Select-Object @{
	Label      = "Name"
	Expression = { if ($_.Name) { $_.Name }
		else { "[No Type]" } }
}, @{ N = "Total Count"; E = { $_.count } } | Sort-Object 'Total Count' -Descending
#endregion

#region Server type with OS count status
$SrvPhysical = @()
$SrvVirtual = @()


$OSNames = ($importCSVData | Select-Object OS_Name -Unique).OS_Name
for ($i = 0; $i -lt $OSNames.Count; $i++) {
	$SrvPhysical += ($importCSVData | Where-Object { (($_.OS_Name -eq $OSNames[$i]) -and ($_.Phy_VM -eq "Physical")) }).count
	$SrvVirtual += ($importCSVData | Where-Object { (($_.OS_Name -eq $OSNames[$i]) -and ($_.Phy_VM -eq "Virtual")) }).count
}

#endregion

#endregion Data collection for Dashboard


#region Dashboard Code
Dashboard -Name 'Windows Server Inventory v0.1 @mol' -FilePath $outputfileHTML {
	Tab -Name 'Dashboard' -IconRegular dot-circle {
		Section -Name 'Summary Chart' -Collapsable -HeaderBackGroundColor Astral {
			Panel {
				$Data1 = @($OS_Counts_Online.'Total Count') #400, 430, 448, 470, 540, 580, 690, 1100, 1200, 1380
				$DataNames1 = @($OS_Counts_Online.Name) #'South Korea', 'Canada', 'United Kingdom', 'Netherlands', 'Italy', 'France', 'Japan', 'United States', 'China', 'Germany'
				Chart -Title 'Operating System counts (ONLINE)' -TitleAlignment center {
					
					ChartBarOptions -Type bar -Distributed
					ChartLegend -Name 'Total'
					for ($i = 0; $i -lt $Data1.Count; $i++) {
						ChartBar -Name $DataNames1[$i] -Value $Data1[$i]
					}
				}
				
			}
			Panel {
				$Data1 = @($OS_Counts_NotOnline.'Total Count') #400, 430, 448, 470, 540, 580, 690, 1100, 1200, 1380
				$DataNames1 = @($OS_Counts_NotOnline.Name) #'South Korea', 'Canada', 'United Kingdom', 'Netherlands', 'Italy', 'France', 'Japan', 'United States', 'China', 'Germany'
				Chart -Title 'Operating System counts (NOT ONLINE)' -TitleAlignment center {
					
					ChartBarOptions -Type bar -Distributed
					ChartLegend -Name 'Total'
					for ($i = 0; $i -lt $Data1.Count; $i++) {
						ChartBar -Name $DataNames1[$i] -Value $Data1[$i]
					}
				}
				
			}
			Panel {
				$Data1 = @($SrvTypes_Counts.'Total Count') #400, 430, 448, 470, 540, 580, 690, 1100, 1200, 1380
				$DataNames1 = @($SrvTypes_Counts.Name) #'South Korea', 'Canada', 'United Kingdom', 'Netherlands', 'Italy', 'France', 'Japan', 'United States', 'China', 'Germany'
				Chart -Title 'Physical or Virtual Type counts' -TitleAlignment center {
					
					ChartBarOptions -Type bar -Distributed
					ChartLegend -Name 'Total'
					for ($i = 0; $i -lt $Data1.Count; $i++) {
						ChartBar -Name $DataNames1[$i] -Value $Data1[$i]
					}
				}
				
			}
			
			Panel {
				$Data1 = @($BMCAgent_Counts.'Total Count') #400, 430, 448, 470, 540, 580, 690, 1100, 1200, 1380
				$DataNames1 = @($BMCAgent_Counts.Name) #'South Korea', 'Canada', 'United Kingdom', 'Netherlands', 'Italy', 'France', 'Japan', 'United States', 'China', 'Germany'
				Chart -Title 'ManageEngine Status' -TitleAlignment center {
					
					ChartBarOptions -Type bar -Distributed
					ChartLegend -Name 'Total'
					for ($i = 0; $i -lt $Data1.Count; $i++) {
						ChartBar -Name $DataNames1[$i] -Value $Data1[$i]
					}
				}
				
			}
			
		}
		
		Section -Name 'Summary Table' -Collapsable -HeaderBackGroundColor Astral {
			Table -DataTable $OS_Counts_Online -PagingOptions 5, 15, 25 { }
			Table -DataTable $OS_Counts_NotOnline -PagingOptions 5, 15, 25 { }
			Table -DataTable $SrvTypes_Counts -PagingOptions 5, 15, 25 { }
			Table -DataTable $BMCAgent_Counts -PagingOptions 5, 15, 25 { }
		}
		
		Section -Name 'All Server OS type' -Collapsable -HeaderBackGroundColor Astral {
			Panel {
				$Data1 = @($OS_Counts_All.'Total Count') #400, 430, 448, 470, 540, 580, 690, 1100, 1200, 1380
				$DataNames1 = @($OS_Counts_All.Name) #'South Korea', 'Canada', 'United Kingdom', 'Netherlands', 'Italy', 'France', 'Japan', 'United States', 'China', 'Germany'
				Chart -Title 'Operating System counts' -TitleAlignment center {
					
					ChartBarOptions -Type bar -Distributed
					ChartLegend -Name 'Total'
					for ($i = 0; $i -lt $Data1.Count; $i++) {
						ChartBar -Name $DataNames1[$i] -Value $Data1[$i]
					}
				}
				
			}
			
		}
		
		Section -Name 'Server Type with OS' -Collapsable -HeaderBackGroundColor Astral {
			Panel {
				$D1 = @($SrvPhysical)
				$D2 = @($SrvVirtual)
				$DN1 = @($OSNames)
				
				
				Chart -Title 'Server Type with OS' -TitleAlignment center {
					ChartLegend -Name 'Physical', 'Virtual' -Color SeaGreen, IndianRed #CoralRed
					ChartBarOptions -Type bar -DataLabelsOffsetX 15
					for ($i = 0; $i -lt $D1.Count; $i++) {
						ChartBar -Name $DN1[$i] -Value $D1[$i], $D2[$i] 
					}
				}
			}
		}
	}
	
	Tab -Name 'UP TIME 40+' -IconRegular dot-circle {
		Table -DataTable $Uptime40UP_List -PagingOptions 15, 25 -Filtering {
			TableConditionalFormatting -Name 'Uptime' -ComparisonType number -Operator ge -Value 50 -Color white -BackgroundColor Crimson
			TableConditionalFormatting -Name 'Uptime' -ComparisonType number -Operator le -Value 50 -Color black -BackgroundColor amber
		}
	}
	
	Tab -Name 'Not Patched 30+ days' -IconRegular dot-circle {
		Table -DataTable $30DaysHotfixAlert_List -PagingOptions 15, 25 -Filtering {
			#TableConditionalFormatting -Name 'FreeSpacePer' -ComparisonType number -Operator le -Value 15 -Color black -BackgroundColor amber 
			$less30days = ((Get-Date).AddDays(-30))

			TableConditionalFormatting -Name 'Hotfix Intalled ON' -ComparisonType date -Operator gt -Value $less30days -Color black -BackgroundColor amber

		}
	}
	
	Tab -Name 'C Disk Space Alerts' -IconRegular dot-circle {
		Table -DataTable $CDiskAlert_List -PagingOptions 15, 25 -Filtering {
			TableConditionalFormatting -Name 'C-Disk-Free %' -ComparisonType number -Operator le -Value 12 -Color white -BackgroundColor Crimson

		}
	}
	
	Tab -Name 'All Server Details' -IconRegular dot-circle {
		Table -DataTable $importCSVData -PagingOptions 15, 25 -Filtering {
			#TableConditionalFormatting -Name 'FreeSpacePer' -ComparisonType number -Operator le -Value 15 -Color black -BackgroundColor amber 
			TableConditionalFormatting -Name 'Uptime' -ComparisonType number -Operator ge -Value 50 -Color white -BackgroundColor Crimson
			TableConditionalFormatting -Name 'C-Disk-Free %' -ComparisonType number -Operator le -Value 12 -Color white -BackgroundColor Crimson

		}
	}
}

#endregion Dashboard Code

#endregion HTML Dashboard

Copy-Item $outputfileHTML "P:\InfraWeb\ServerInventory\Home.html" -Force -Verbose   

# Get End Time
$EndMain = (Get-Date)
$MainElapsedTime = $EndMain - $startMain
$MainElapsedTimeOut = [Math]::Round(($MainElapsedTime.TotalMinutes), 3)


"[Total Elapsed Time] $MainElapsedTimeOut Min. for Objects [$($ObjectCount)]" | Out-File ($SCRIPT_PARENT + "\JobStatus_$((Get-Date).ToString('MM-dd-yyyy')).txt") -Append
"/\____________________________________________________/\" | Out-File ($SCRIPT_PARENT + "\JobStatus_$((Get-Date).ToString('MM-dd-yyyy')).txt") -Append
Add-WriteHost "[Total Elapsed Time] $MainElapsedTimeOut Min. for Objects [$($ObjectCount)]"
Add-WriteHost "[END] Job End" -Color Yellow

<# ------- Commented

#$MailTextT =  Get-Content $outputfileHTML

$Sig = "<html><p class=MsoNormal><o:p>&nbsp;</o:p></p><B> Regards, <p> Amol Patil</B></p></html>"
$Top = "<html> [Total Elapsed Time] $MainElapsedTimeOut Min. for Objects [$($ObjectCount)] </html>"
$MailText = $Top + $Sig
$smtpServer = "SMTP" # SMTP server
$smtpFrom = "FromAddress"
$smtpTo = "TOAddress"
$messageSubject = "Server UP TIME > $(Get-date) "
$messageBody = $MailText #+  $MailTextT 
$Attachment = $outputfileHTML # If any attachment then you can define the  $Attachment


$mailMessageParameters = @{
	From	   = $smtpFrom
	To		   = $smtpTo
	Subject    = $messageSubject
	SmtpServer = $smtpServer
	Body	   = $messageBody
	Attachment = $Attachment
}

Send-MailMessage @mailMessageParameters -BodyAsHtml -Verbose
Write-Host "Email has been sent..... $(Get-date -format "dd-MMM-yyyy HH:mm:ss")" -ForegroundColor Green
#>



###############################################
# Author: Amol
# Date: 05/13/2025
# Description:  Schedule VM Snapshot tasks from connected vCenter.
# You can schedule for one or more VMs from same or multiple vCenters, just need to connect each vcenter first. 
# Also it will send email once task completed if Email notification is configured.
###############################################


# Connect-VIServer vcname.domain.com

$vmNames = @(
'vm1'
)

$snapTime = Get-Date "05/13/2025 18:10"

$snapName = 'Note - Before patching - By-Amol'

$snapDescription = 'Scheduled snapshot ' + $snapName

$snapMemory = $true

$snapQuiesce = $false

$emailAddr = "amolsp777@live.com"

###############

Foreach($vmName in $vmNames){

$vm = Get-VM -Name $vmName | Where-Object{$_.PowerState -eq "PoweredOn"}

$si = get-view ServiceInstance

$scheduledTaskManager = Get-View $si.Content.ScheduledTaskManager

$spec = New-Object VMware.Vim.ScheduledTaskSpec

$spec.Name = "Schedule-take a snapshot of $($vm.Name)" -join ' '

$spec.Description = "Schedule-take a snapshot of $($vm.Name)"

$spec.Enabled = $true

$spec.Notification = $emailAddr

$spec.Scheduler = New-Object VMware.Vim.OnceTaskScheduler

$spec.Scheduler.runat = $snapTime

$spec.Action = New-Object VMware.Vim.MethodAction

$spec.Action.Name = "CreateSnapshot_Task"

@($snapName,$snapDescription,$snapMemory,$snapQuiesce) | %{

    $arg = New-Object VMware.Vim.MethodActionArgument

    $arg.Value = $_

    $spec.Action.Argument += $arg

}

$scheduledTaskManager.CreateObjectScheduledTask($vm.ExtensionData.MoRef, $spec)

}

Function Get-VIScheduledTasks {
PARAM ( [switch]$Full )
if ($Full) {
# Note: When returning the full View of each Scheduled Task, all date times are in UTC
(Get-View ScheduledTaskManager).ScheduledTask | %{ (Get-View $_).Info }
} else {
# By default, lets only return common headers and convert all date/times to local values
(Get-View ScheduledTaskManager).ScheduledTask | %{ (Get-View $_ -Property Info).Info } |
Select-Object Name, Description, Enabled, Notification, LastModifiedUser, State, Entity,
@{N=”EntityName”;E={ (Get-View $_.Entity -Property Name).Name }},
@{N=”LastModifiedTime”;E={$_.LastModifiedTime.ToLocalTime()}},
@{N=”NextRunTime”;E={$_.NextRunTime.ToLocalTime()}},
@{N=”PrevRunTime”;E={$_.LastModifiedTime.ToLocalTime()}},
@{N=”ActionName”;E={$_.Action.Name}}
}
}

Function Get-VMScheduledSnapshots {
Get-VIScheduledTasks | ?{$_.ActionName -eq ‘CreateSnapshot_Task’}# |
#Select-Object @{N=”VMName”;E={$_.EntityName}}, Name, NextRunTime, Notification
}


Get-VMScheduledSnapshots | Where-Object {(($_.name -like "Schedule-take a snapshot*") -and ($_.NextRunTime -ne $null))} | Select-Object Name,NextRunTime,Notification,LastModifiedTime | ft 


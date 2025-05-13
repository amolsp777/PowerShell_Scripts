###############################################
# Author: Amol
# Date: 05/13/2025
# Description:  Get the VM scheduled tasks from connected vCenter.
###############################################


# Connect-VIServer vcname.domain.com

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
Get-VIScheduledTasks | Where-Object{$_.ActionName -eq ‘CreateSnapshot_Task’} #|
#Select-Object @{N=”VMName”;E={$_.EntityName}}, Name, NextRunTime, Notification
}

Get-VIScheduledTasks | Format-Table -AutoSize

Get-VMScheduledSnapshots | Select-Object Name,ActionName,NextRunTime,Notification,LastModifiedTime,PrevRunTime | Format-Table  #| where {$_.vmname -eq $vm.Name}
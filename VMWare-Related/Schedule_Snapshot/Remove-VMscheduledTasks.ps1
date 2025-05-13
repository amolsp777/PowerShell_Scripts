
###############################################
# Author: Amol
# Date: 05/13/2025
# Description:  Remove the VM scheduled tasks from connected vCenter.
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
        @{N="EntityName";E={ (Get-View $_.Entity -Property Name).Name }},
        @{N="LastModifiedTime";E={$_.LastModifiedTime.ToLocalTime()}},
        @{N="NextRunTime";E={$_.NextRunTime.ToLocalTime()}},
        @{N="PrevRunTime";E={$_.LastModifiedTime.ToLocalTime()}},
        @{N="ActionName";E={$_.Action.Name}},
        @{N="ScheduledTask";E={$_.ScheduledTask}}
    }
}

Function Get-VMScheduledSnapshots {
    Get-VIScheduledTasks | ?{$_.ActionName -eq 'CreateSnapshot_Task'}
}

Get-VMScheduledSnapshots | Select Name,ActionName,NextRunTime,Notification,LastModifiedTime,PrevRunTime | ft  #| where {$_.vmname -eq $vm.Name}

Function Remove-OldSnapshots {
    $thresholdDate = (Get-Date).AddDays(-7)
    $oldSnapshots = Get-VMScheduledSnapshots | ?{$_.NextRunTime -lt $thresholdDate}
    foreach ($task in $oldSnapshots) {
        if ($task -and $task.ScheduledTask) {
            $taskView = (Get-View -Id $task.ScheduledTask).MoRef.Value
            if ($taskView) {
                $taskView.RemoveScheduledTask()
                Write-Output "Removed scheduled task: $($task.Name)"
            } else {
                Write-Output "Failed to get view for task: $($task.Name)"
            }
        } else {
            Write-Output "Invalid task object: $($task.Name)"
        }
    }
}

$scheduledTaskManager = Get-View ScheduledTaskManager

$scheduledTaskManager.RemoveScheduledTask($task.ScheduledTask.MoRef.value)

# Call the function to remove old snapshots
Remove-OldSnapshots

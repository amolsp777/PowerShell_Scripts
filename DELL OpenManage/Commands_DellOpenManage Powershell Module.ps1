####### DellOpenManage Powershell Module #######

###############################################
# Author: Amol
# Date: '$(Get-Date)'
# Description: Enter a description here.
###############################################

#region Connect OME server
$credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "fsdgdsfgdf", $(ConvertTo-SecureString -Force -AsPlainText "!")
Connect-OMEServer -Name "delllldddd" -Credentials $credentials -IgnoreCertificateWarning
#endregion

#region Get Baseline
Get-OMEFirmwareBaseline
#endregion 

Get-OMEFirmwareBaseline | Format-Table
"AllLatest" | Get-OMEFirmwareBaseline | Get-OMEFirmwareCompliance | Format-Table

#region Get device firmware compliance report. BIOS only.
"Dell Baseline" | Get-OMEFirmwareBaseline | Get-OMEFirmwareCompliance -ComponentFilter "BIOS" |
Select-Object -Property ServiceTag, DeviceModel, DeviceName, CurrentVersion, Version, UpdateAction, Criticality, ComplianceStatus, Name |
Sort-Object CurrentVersion | Format-Table
#endregion

#region Get device firmware compliance report
$devices = $("GYUZDW2" | Get-OMEDevice -FilterBy "ServiceTag")
"Dell Baseline"  | Get-OMEFirmwareBaseline | Get-OMEFirmwareCompliance -DeviceFilter $devices |
Select-Object -Property ServiceTag, DeviceModel, DeviceName, CurrentVersion, Version, UpdateAction, Criticality, ComplianceStatus, Name | Format-Table
#endregion

#region Get device firmware compliance report. Multiple component filter
"Dell Baseline"  | Get-OMEFirmwareBaseline | Get-OMEFirmwareCompliance -ComponentFilter "BIOS", "iDRAC" |
Select-Object -Property ServiceTag, DeviceModel, DeviceName, CurrentVersion, Version, UpdateAction, ComplianceStatus, Name |
Sort-Object CurrentVersion | Format-Table
#endregion
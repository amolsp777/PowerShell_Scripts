# VMWare - OneLincers


### Connect vCenter Server
Connect with Windows default credentials.
```powershell 
$VC = "myvc.vsphere.com"
Connect-viserver -Server $VC 
```

Connect with Provided credentials.
```powershell 
$VC = "myvc.vsphere.com"
$myCredentials = Get-Credential
Connect-viserver -Server $VC -Credential $myCredentials
```
More details here - [Connect-VIServer](https://developer.vmware.com/docs/powercli/latest/vmware.vimautomation.core/commands/connect-viserver/#Default)


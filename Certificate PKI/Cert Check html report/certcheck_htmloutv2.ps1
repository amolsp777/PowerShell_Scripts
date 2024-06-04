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


$SCRIPT_PARENT   = Split-Path -Parent $MyInvocation.MyCommand.Definition 

$Urls = @()
<#
$Urls = "https://example.com/",
        "https://google.com/"
#>

# Create sites.txt file at the location where this script is saved and will execute.
# Enter the required sites in that file in each line.
# This script will pick the each site and check the cert.
# comment below line you you want to take urls within this code. from above commneted part. 

$Urls = Get-Content ($SCRIPT_PARENT + "\sites.txt")

$props = @()

[int]$MinimumCertAgeDays = 60

$ErrorActionPreference= 'silentlycontinue'

Foreach ($url in $Urls)
{
[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

$req = [Net.HttpWebRequest]::Create($url)
$req.GetResponse() | Out-Null
#$req.ServicePoint.Certificate.GetExpirationDateString()

$ExpirationDate = $req.ServicePoint.Certificate.GetExpirationDateString()
$certissuer = $req.ServicePoint.Certificate.Issuer
$DayCount = ( $( Get-date $ExpirationDate ) - $( Get-Date ) ).Days

If($DayCount -le 0){$certstatus = "Expired"}
elseif(($DayCount -le $MinimumCertAgeDays) -and ($DayCount -gt 0) ){$certstatus = "Expiring"}
Else{$certstatus = "Valid"}

 
            $Results = New-Object Object
           $Results | Add-Member -Type NoteProperty -Name 'URL' -Value $url
           $Results | Add-Member -Type NoteProperty -Name 'ExpirationDate' -Value $ExpirationDate
           $Results | Add-Member -Type NoteProperty -Name 'CertStatus' -Value $certstatus 
           $Results | Add-Member -Type NoteProperty -Name 'Exp in Days' -Value $DayCount 
           $Results | Add-Member -Type NoteProperty -Name 'Cert Issuer' -Value $certissuer


           $props += $Results 
     
}


Write-Output $props

$expiredcert =@()
Foreach($ur in $props){
    if ($ur.CertStatus -eq "Expired") {
    $expiredcert += $ur
    }

}

$expiringcert =@()
Foreach($ur1 in $props){
    if (($ur1.'Expiring in Days' -le $MinimumCertAgeDays) -and ($ur1.CertStatus -like "Expiring") ){
    $expiringcert += $ur1
    }

}


#region HTML BODY List
$Date = Get-Date -Format "MMM-dd-yyyy"
$htmloutput = ($SCRIPT_PARENT + "\certcheck.html")

$htmlBodyStyle = "<style>"
$htmlBodyStyle = $htmlBodyStyle + "BODY {color:#374141;background-color:#ffffff;font-size:10pt;font-family:'Calibri','trebuchet ms', helvetica, sans-serif;font-weight:normal;padding-:5px;margin:5px;overflow:auto;}"
$htmlBodyStyle = $htmlBodyStyle + "Table {font-family:'Verdana', Verdana, Helvetica, sans-serif;font-size: 12px;border-collapse: collapse;}"
$htmlBodyStyle = $htmlBodyStyle + "Table td, Table th {border: 2px solid #ddd;padding: 3px;text-align:left;white-space:nowrap}"
$htmlBodyStyle = $htmlBodyStyle + "Table tr:nth-child(even){background-color: #f2f2f2;}"
$htmlBodyStyle = $htmlBodyStyle + "Table tr:hover {background-color: #ddd;}"
$htmlBodyStyle = $htmlBodyStyle + "Table th {padding-top: 2px;padding-bottom: 2px;text-align: center;background-color: #2374a0;color: #f2f2f2;}"
$htmlBodyStyle = $htmlBodyStyle + "div {border: 1px solid gray;padding: 2px;}"
$htmlBodyStyle = $htmlBodyStyle + "h1 {text-align: center;color: #005580;font-family: 'Verdana', Verdana, Helvetica, sans-serif;}"
$htmlBodyStyle = $htmlBodyStyle + "h3 {text-align: left;color: #005580;font-family: 'Verdana', Verdana, Helvetica, sans-serif;}"
$htmlBodyStyle = $htmlBodyStyle + "h4 {text-align: left;color: #005580;font-family: 'Verdana', Verdana, Helvetica, sans-serif;}"
$htmlBodyStyle = $htmlBodyStyle + "p {text-align: left;letter-spacing: 2px;font-family: 'Verdana', Verdana, Helvetica, sans-serif;}"
$htmlBodyStyle = $htmlBodyStyle + ".warning {color: #FFA500;}"
$htmlBodyStyle = $htmlBodyStyle + ".error {color: #FF0000;}"
$htmlBodyStyle = $htmlBodyStyle + "</style>"

$HTML = "<h1 align='center'>--- Web SSL Cert Expiry Monitor ---</h1></br>"
$HTML += "<h4 align='Left'><font color='#006699'>Date: $Date</font></h4></br>"

$expiredcertCount = $props | Where-Object{$_.'CertStatus' -eq "Expired"}
If(($expiredcertCount).count -gt 0 ){
$HTML += "<h3>Expired Certs</h3>"
$HTML += $expiredcert | ConvertTo-HTML -head $htmlBodyStyle
}

$expiringcertCount = $props | Where-Object{$_.'CertStatus' -eq "Expiring"}
If(($expiringcertCount).count -gt 0 ){
$HTML += "<h3>Expiring Certs</h3>"
$HTML += $expiringcert | ConvertTo-HTML -head $htmlBodyStyle

}

$HTML += "</br><h3>All Web sites in monitoring</h3>"
$HTML += $props | sort 'CertStatus','Exp in Days'  | ConvertTo-HTML -head $htmlBodyStyle

$HTML += "<h4><font color='Red'><b>Note: </b></h4><h4>Cert expiry warning minimum days : $MinimumCertAgeDays</h4>"

Foreach($u in $props){
    if ($u.'Exp in Days' -le $MinimumCertAgeDays) {
        
        $u1 = $u.'Exp in Days'
        $expiryColor = ""
        if (($u.'Exp in Days' -le $MinimumCertAgeDays) -and ($u.'Exp in Days' -gt 0)  ){
        Write-Host "Expiring URL $($u.Url)" -ForegroundColor Yellow
            $expiryColor = "color:Orange;"
            
        }
        $HTML = $HTML -Replace ($u.'Exp in Days', "<span style='$expiryColor'>$($u1)</span>")
    }
}


Foreach($u in $props){
    if ($u.'Exp in Days' -le $MinimumCertAgeDays) {

        $u1 = $u.'Exp in Days'
        $expiryColor = ""
        if (($u.'Exp in Days' -le 0)  ){
        Write-Host "Expired URL $($u.Url)" -ForegroundColor Red
            $expiryColor = "color:Red;"
        }
        $HTML = $HTML -Replace ($u.'Exp in Days', "<span style='$expiryColor'>$($u1)</span>")
    }
}

$HTML = $HTML -Replace ('Valid', '<font color="green">Valid</font>')
$HTML = $HTML -Replace ('Expired', '<font color="red">Expired</font>')
$HTML = $HTML -Replace ('Expiring', '<font color="Orange">Expiring</font>')

$HTML | Out-File $htmloutput
#endregion 

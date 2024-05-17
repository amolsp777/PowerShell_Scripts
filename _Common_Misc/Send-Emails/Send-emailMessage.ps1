$smtpServer = "smtp.mailserver.com" # SMTP server
$smtpFrom = "amolpa@mailserver.com"
$smtpTo = "amolpa@mailserver.com" 
$messageSubject = "Email testing from $($smtpServer)_($(get-date -UFormat %D))"
$messageBody = "Hello   email sent from $env:COMPUTERNAME on $(Get-date)"
#$Attachment = $path
<# If any attachment then you can define the  $Attachment#>

$mailMessageParameters = @{
    From       = $smtpFrom
    To         = $smtpTo
    Subject    = $messageSubject
    SmtpServer = $smtpServer
    Body       = $messageBody
    # Attachment = $Attachment
}
Send-MailMessage @mailMessageParameters -BodyAsHtml
<#
.DESCRIPTION
    List all expired secrets and certificates for your app regs
.AUTHOR
    Odd Arvid Knudsen
#>

# Parameters
$tenantId = "Your tenant id"
$clientId = "Your clientID"
$ClientSecret = "Your client secret"

# Import modules
#Import-Module Microsoft.Graph.Applications

# Convert client secret to a secure string
$secureClientSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force

# Create a credential object
$credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $secureClientSecret

# Connect to Microsoft Graph using service principal
Connect-MgGraph -TenantId $tenantId -Credential $credentials

# Define lists to hold expired and expiring credentials
$expiredSecrets = New-Object System.Collections.ArrayList
$expiringSecrets = New-Object System.Collections.ArrayList
$expiredCertificates = New-Object System.Collections.ArrayList
$expiringCertificates = New-Object System.Collections.ArrayList

# Get all applications
$applications = Get-MgApplication -All

# Get current date and calculate the date 30 days from now
$currentDate = Get-Date
$futureDate = $currentDate.AddDays(30)

foreach ($app in $applications) {
    # Get the password credentials (secrets) for the application
    $passwordCredentials = $app.PasswordCredentials
    
    foreach ($credential in $passwordCredentials) {
        if ($credential.EndDateTime -le $futureDate -and $credential.EndDateTime -gt $currentDate) {
            $properties1 = @{
                AppName   = $app.DisplayName
                AppId     = $app.AppId
                SecretId  = $credential.KeyId
                EndDate   = $credential.EndDateTime
            }
            $expiringSecrets.add((New-Object psobject -Property $properties1))
        } elseif ($credential.EndDateTime -lt $currentDate) {
            $properties2 = @{
                AppName   = $app.DisplayName
                AppId     = $app.AppId
                SecretId  = $credential.KeyId
                EndDate   = $credential.EndDateTime
            }
            $expiredSecrets.add((New-Object psobject -Property $properties2))
        }
    }
    
    # Get the certificate credentials for the application
    $certificateCredentials = $app.KeyCredentials
    
    foreach ($cert in $certificateCredentials) {
        if ($cert.EndDateTime -le $futureDate -and $cert.EndDateTime -gt $currentDate) {
            $properties3 = @{
                AppName   = $app.DisplayName
                AppId     = $app.AppId
                CertId    = $cert.KeyId
                EndDate   = $cert.EndDateTime
            }
            $expiringCertificates.add((New-Object psobject -Property $properties3))
        } elseif ($cert.EndDateTime -lt $currentDate) {
            $properties4 = @{
                AppName   = $app.DisplayName
                AppId     = $app.AppId
                CertId    = $cert.KeyId
                EndDate   = $cert.EndDateTime
            }
            $expiredCertificates.add((New-Object psobject -Property $properties4))
        }
    }
}

# Sort credentials by end date
$expiringSecrets = $expiringSecrets | Sort-Object EndDate
$expiredSecrets = $expiredSecrets | Sort-Object EndDate
$expiringCertificates = $expiringCertificates | Sort-Object EndDate
$expiredCertificates = $expiredCertificates | Sort-Object EndDate

# Generate HTML body for the email
$htmlBody = @"
<html>
<head>
<style>
    table { font-family: Arial, sans-serif; border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #dddddd; text-align: left; padding: 8px; }
    th { background-color: #f2f2f2; }
</style>
</head>
<body>
<h2>Azure AD Application Secrets and certificates</h2>
<h3>Secrets expiring in the Next 30 Days</h3>
<table>
    <tr>
        <th>App Name</th>
        <th>App ID</th>
        <th>Secret ID</th>
        <th>End Date</th>
    </tr>
"@

foreach ($secret in $expiringSecrets) {
    $htmlBody += "<tr>"
    $htmlBody += "<td><b>$($secret.AppName)</b></td>"
    $htmlBody += "<td><b>$($secret.AppId)</b></td>"
    $htmlBody += "<td><b>$($secret.SecretId)</b></td>"
    $htmlBody += "<td><b>$($secret.EndDate)</b></td>"
    $htmlBody += "</tr>"
}

$htmlBody += @"
</table>
<h3>Secret Already Expired</h3>
<table>
    <tr>
        <th>App Name</th>
        <th>App ID</th>
        <th>Secret ID</th>
        <th>End Date</th>
    </tr>
"@

foreach ($secret in $expiredSecrets) {
    $htmlBody += "<tr>"
    $htmlBody += "<td>$($secret.AppName)</td>"
    $htmlBody += "<td>$($secret.AppId)</td>"
    $htmlBody += "<td>$($secret.SecretId)</td>"
    $htmlBody += "<td>$($secret.EndDate)</td>"
    $htmlBody += "</tr>"
}

$htmlBody += @"

</table>
<h3>Cert expiring in the Next 30 Days</h3>
<table>
    <tr>
        <th>App Name</th>
        <th>App ID</th>
        <th>Secret ID</th>
        <th>End Date</th>
    </tr>
"@

foreach ($secret in $expiringCertificates) {
    $htmlBody += "<tr>"
    $htmlBody += "<td>$($secret.AppName)</td>"
    $htmlBody += "<td>$($secret.AppId)</td>"
    $htmlBody += "<td>$($secret.SecretId)</td>"
    $htmlBody += "<td>$($secret.EndDate)</td>"
    $htmlBody += "</tr>"
}

$htmlBody += @"

</table>
<h3>Cert already Expired</h3>
<table>
    <tr>
        <th>App Name</th>
        <th>App ID</th>
        <th>Secret ID</th>
        <th>End Date</th>
    </tr>
"@

foreach ($secret in $expiredCertificates) {
    $htmlBody += "<tr>"
    $htmlBody += "<td>$($secret.AppName)</td>"
    $htmlBody += "<td>$($secret.AppId)</td>"
    $htmlBody += "<td>$($secret.SecretId)</td>"
    $htmlBody += "<td>$($secret.EndDate)</td>"
    $htmlBody += "</tr>"
}

$htmlBody += @"

</table>
</body>
</html>
"@

# Define email parameters
$smtpServer = "smtp.azurecomm.net"  
$smtpFrom = "noreply@yourdomain.no"
$smtpTo = "toaddress@yourdomain.no"
$messageSubject = "Expired Azure AD Application Credentials"
$smtpUsername = "xxxxx"  # Your SMTP server username
$smtpPassword = "xxxxx"  # Your SMTP server password

# Create the email message
$message = New-Object System.Net.Mail.MailMessage
$message.From = $smtpFrom
foreach ($smtp in $smtpTo) {
    $message.To.Add($smtp)
}
$message.Subject = $messageSubject
$message.Body = $htmlBody
$message.IsBodyHtml = $true

# Configure SMTP client
$smtp = New-Object Net.Mail.SmtpClient($smtpServer, 587)  
$smtp.EnableSsl = $true
$smtp.Credentials = New-Object System.Net.NetworkCredential($smtpUsername, $smtpPassword)

# Send the email
try {
    $smtp.Send($message)
    Write-Output "Email sent successfully to: $smtpTo"
} catch {
    Write-Output "Failed to send email. $_"
}


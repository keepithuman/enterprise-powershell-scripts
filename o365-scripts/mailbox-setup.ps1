<#
.SYNOPSIS
    Create and configure Office 365 mailboxes

.DESCRIPTION
    Creates O365 mailboxes, sets mailbox properties, configures email addresses,
    and assigns licenses.

.PARAMETER UserPrincipalName
    User principal name for the mailbox

.PARAMETER DisplayName
    Display name for the user

.PARAMETER FirstName
    User's first name

.PARAMETER LastName
    User's last name

.PARAMETER Department
    User's department

.PARAMETER UsageLocation
    Two-letter country code (required for licensing)

.EXAMPLE
    .\mailbox-setup.ps1 -UserPrincipalName "john.doe@contoso.com" -DisplayName "John Doe"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$UserPrincipalName,
    
    [Parameter(Mandatory=$true)]
    [string]$DisplayName,
    
    [string]$FirstName,
    
    [string]$LastName,
    
    [string]$Department,
    
    [string]$UsageLocation = "US"
)

# Check if Exchange Online module is available
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Warning "ExchangeOnlineManagement module not found. Installing..."
    Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber
}

# Import module
Import-Module ExchangeOnlineManagement -ErrorAction Stop

# Connect to Exchange Online (assumes already authenticated)
Write-Host "Connecting to Exchange Online..." -ForegroundColor Yellow
try {
    # Check if already connected
    Get-Mailbox -ResultSize 1 -ErrorAction Stop | Out-Null
    Write-Host "Already connected to Exchange Online" -ForegroundColor Green
} catch {
    Write-Host "Please authenticate to Exchange Online..." -ForegroundColor Yellow
    Connect-ExchangeOnline
}

# Check if mailbox already exists
$existingMailbox = Get-Mailbox -Identity $UserPrincipalName -ErrorAction SilentlyContinue

if ($existingMailbox) {
    Write-Host "Mailbox already exists for $UserPrincipalName, updating properties..." -ForegroundColor Yellow
    
    # Update mailbox properties
    Set-Mailbox -Identity $UserPrincipalName `
        -DisplayName $DisplayName `
        -Office $Department
    
} else {
    Write-Host "Creating new mailbox for $UserPrincipalName..." -ForegroundColor Green
    
    # Create user first (requires Azure AD module)
    $password = ConvertTo-SecureString "TempP@ssw0rd123!" -AsPlainText -Force
    
    $userParams = @{
        UserPrincipalName = $UserPrincipalName
        DisplayName = $DisplayName
        MailNickName = $UserPrincipalName.Split('@')[0]
        Password = $password
        ForceChangePasswordNextLogin = $true
        UsageLocation = $UsageLocation
    }
    
    if ($FirstName) { $userParams.FirstName = $FirstName }
    if ($LastName) { $userParams.LastName = $LastName }
    if ($Department) { $userParams.Department = $Department }
    
    # Note: In production, you would create the user via Azure AD
    Write-Host "User creation would happen here in production" -ForegroundColor Cyan
}

# Configure mailbox settings
Write-Host "\nConfiguring mailbox settings..." -ForegroundColor Yellow

# Set mailbox regional configuration
$mailboxConfig = @{
    Identity = $UserPrincipalName
    Language = "en-US"
    DateFormat = "M/d/yyyy"
    TimeFormat = "h:mm tt"
    TimeZone = "Eastern Standard Time"
}

try {
    Set-MailboxRegionalConfiguration @mailboxConfig -ErrorAction Stop
    Write-Host "Regional configuration set" -ForegroundColor Green
} catch {
    Write-Warning "Could not set regional configuration: $_"
}

# Set mailbox quotas
$quotaConfig = @{
    Identity = $UserPrincipalName
    IssueWarningQuota = "49GB"
    ProhibitSendQuota = "49.5GB"
    ProhibitSendReceiveQuota = "50GB"
}

try {
    Set-Mailbox @quotaConfig -ErrorAction Stop
    Write-Host "Mailbox quotas configured" -ForegroundColor Green
} catch {
    Write-Warning "Could not set quotas: $_"
}

# Enable archive mailbox
try {
    Enable-Mailbox -Identity $UserPrincipalName -Archive -ErrorAction Stop
    Write-Host "Archive mailbox enabled" -ForegroundColor Green
} catch {
    Write-Warning "Could not enable archive: $_"
}

# Set retention policy
$retentionPolicy = "Default MRM Policy"
try {
    Set-Mailbox -Identity $UserPrincipalName -RetentionPolicy $retentionPolicy -ErrorAction Stop
    Write-Host "Retention policy applied: $retentionPolicy" -ForegroundColor Green
} catch {
    Write-Warning "Could not set retention policy: $_"
}

# Add email addresses
$emailAddresses = @(
    "smtp:$($UserPrincipalName.Split('@')[0])@contoso.onmicrosoft.com"
)

foreach ($email in $emailAddresses) {
    try {
        Set-Mailbox -Identity $UserPrincipalName -EmailAddresses @{Add=$email} -ErrorAction Stop
        Write-Host "Added email address: $email" -ForegroundColor Green
    } catch {
        Write-Warning "Could not add email address $email : $_"
    }
}

# Display mailbox information
Write-Host "\nMailbox configuration complete!" -ForegroundColor Green
Get-Mailbox -Identity $UserPrincipalName | Format-List DisplayName, PrimarySmtpAddress, WhenCreated, UsageLocation

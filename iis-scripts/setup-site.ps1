<#
.SYNOPSIS
    Configure IIS website and application pool

.DESCRIPTION
    Creates or updates IIS websites with associated application pools,
    SSL bindings, and basic authentication settings.

.PARAMETER SiteName
    Name of the IIS site to create or update

.PARAMETER Port
    Port number for the site binding

.PARAMETER AppPool
    Application pool name (defaults to site name)

.PARAMETER PhysicalPath
    Physical path for the website files

.PARAMETER EnableSSL
    Enable SSL binding

.EXAMPLE
    .\setup-site.ps1 -SiteName "MyApp" -Port 443 -EnableSSL
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SiteName,
    
    [Parameter(Mandatory=$true)]
    [int]$Port,
    
    [string]$AppPool = $SiteName,
    
    [string]$PhysicalPath = "C:\inetpub\wwwroot\$SiteName",
    
    [switch]$EnableSSL
)

# Import IIS module
Import-Module WebAdministration -ErrorAction Stop

# Create physical path if it doesn't exist
if (-not (Test-Path $PhysicalPath)) {
    New-Item -Path $PhysicalPath -ItemType Directory -Force | Out-Null
    Write-Host "Created directory: $PhysicalPath" -ForegroundColor Green
}

# Create or update application pool
if (Test-Path "IIS:\AppPools\$AppPool") {
    Write-Host "Application pool '$AppPool' already exists, updating..." -ForegroundColor Yellow
} else {
    New-WebAppPool -Name $AppPool
    Write-Host "Created application pool: $AppPool" -ForegroundColor Green
}

# Configure application pool
Set-ItemProperty -Path "IIS:\AppPools\$AppPool" -Name processIdentity.identityType -Value ApplicationPoolIdentity
Set-ItemProperty -Path "IIS:\AppPools\$AppPool" -Name recycling.periodicRestart.time -Value "00:00:00"
Set-ItemProperty -Path "IIS:\AppPools\$AppPool" -Name managedRuntimeVersion -Value "v4.0"
Set-ItemProperty -Path "IIS:\AppPools\$AppPool" -Name enable32BitAppOnWin64 -Value $false

# Create or update website
if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
    Write-Host "Website '$SiteName' already exists, updating..." -ForegroundColor Yellow
    Set-ItemProperty "IIS:\Sites\$SiteName" -Name physicalPath -Value $PhysicalPath
    Set-ItemProperty "IIS:\Sites\$SiteName" -Name applicationPool -Value $AppPool
} else {
    New-Website -Name $SiteName -Port $Port -PhysicalPath $PhysicalPath -ApplicationPool $AppPool
    Write-Host "Created website: $SiteName" -ForegroundColor Green
}

# Configure bindings
$binding = Get-WebBinding -Name $SiteName -Port $Port -ErrorAction SilentlyContinue
if (-not $binding) {
    if ($EnableSSL) {
        New-WebBinding -Name $SiteName -Protocol https -Port $Port -IPAddress "*"
        Write-Host "Added HTTPS binding on port $Port" -ForegroundColor Green
    } else {
        New-WebBinding -Name $SiteName -Protocol http -Port $Port -IPAddress "*"
        Write-Host "Added HTTP binding on port $Port" -ForegroundColor Green
    }
}

# Set additional configurations
Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/anonymousAuthentication" `
    -Name enabled -Value $true -PSPath "IIS:\Sites\$SiteName"

Set-WebConfigurationProperty -Filter "/system.webServer/security/authentication/windowsAuthentication" `
    -Name enabled -Value $false -PSPath "IIS:\Sites\$SiteName"

# Create default document
$defaultDoc = Join-Path $PhysicalPath "index.html"
if (-not (Test-Path $defaultDoc)) {
    @"
<!DOCTYPE html>
<html>
<head>
    <title>$SiteName</title>
</head>
<body>
    <h1>Welcome to $SiteName</h1>
    <p>Site configured successfully on $(Get-Date)</p>
</body>
</html>
"@ | Out-File $defaultDoc -Encoding UTF8
    Write-Host "Created default index.html" -ForegroundColor Green
}

# Start website and app pool
Start-WebAppPool -Name $AppPool -ErrorAction SilentlyContinue
Start-Website -Name $SiteName -ErrorAction SilentlyContinue

Write-Host "\nWebsite configuration complete!" -ForegroundColor Green
Write-Host "URL: http$(if($EnableSSL){'s'})://localhost:$Port" -ForegroundColor Cyan

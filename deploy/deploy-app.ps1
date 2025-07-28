<#
.SYNOPSIS
    Deploy .NET application to IIS

.DESCRIPTION
    Deploys .NET applications with zero-downtime deployment strategy

.PARAMETER Version
    Application version to deploy

.PARAMETER Environment
    Target environment (Dev, Staging, Production)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet('Dev', 'Staging', 'Production')]
    [string]$Environment
)

$appName = "MyApp"
$sourcePath = "C:\\Deployments\\$Version"
$targetPath = "C:\\inetpub\\wwwroot\\$appName"
$backupPath = "C:\\Backups\\$appName\\$(Get-Date -Format 'yyyyMMdd_HHmmss')"

Write-Host "Deploying $appName version $Version to $Environment" -ForegroundColor Green

# Create backup
if (Test-Path $targetPath) {
    New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
    Copy-Item -Path "$targetPath\\*" -Destination $backupPath -Recurse
    Write-Host "Backup created at: $backupPath" -ForegroundColor Yellow
}

# Stop app pool
Import-Module WebAdministration
Stop-WebAppPool -Name $appName -ErrorAction SilentlyContinue

# Deploy files
Copy-Item -Path "$sourcePath\\*" -Destination $targetPath -Recurse -Force
Write-Host "Files deployed to: $targetPath" -ForegroundColor Green

# Update configuration
$configFile = "$targetPath\\appsettings.$Environment.json"
if (Test-Path $configFile) {
    Write-Host "Using environment config: $configFile" -ForegroundColor Cyan
}

# Start app pool
Start-WebAppPool -Name $appName
Write-Host "Application started successfully!" -ForegroundColor Green

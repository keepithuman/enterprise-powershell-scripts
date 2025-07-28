<#
.SYNOPSIS
    Install developer tools and configure environment

.PARAMETER Profile
    Development profile to install (WebDev, DataScience, FullStack)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('WebDev', 'DataScience', 'FullStack')]
    [string]$Profile
)

# Ensure Chocolatey is installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

# Define tool sets
$toolSets = @{
    WebDev = @('git', 'nodejs', 'vscode', 'docker-desktop', 'postman')
    DataScience = @('git', 'python', 'anaconda3', 'vscode', 'r.project')
    FullStack = @('git', 'nodejs', 'python', 'vscode', 'docker-desktop', 'postman', 'mongodb')
}

$tools = $toolSets[$Profile]

Write-Host "Installing $Profile development environment..." -ForegroundColor Green

foreach ($tool in $tools) {
    Write-Host "Installing $tool..." -ForegroundColor Yellow
    choco install $tool -y --no-progress
}

# Configure Git
if ($tools -contains 'git') {
    git config --global init.defaultBranch main
    git config --global core.autocrlf true
    Write-Host "Git configured" -ForegroundColor Green
}

# Set environment variables
[Environment]::SetEnvironmentVariable("DEV_PROFILE", $Profile, "User")

Write-Host "\nDevelopment environment setup complete!" -ForegroundColor Green
Write-Host "Installed profile: $Profile" -ForegroundColor Cyan
Write-Host "Tools installed: $($tools -join ', ')" -ForegroundColor Cyan

<#
.SYNOPSIS
    Apply security hardening based on CIS benchmarks

.DESCRIPTION
    Applies security hardening settings to Windows servers including
    password policies, audit settings, and security configurations.

.PARAMETER Level
    CIS benchmark level (1 or 2)

.PARAMETER GenerateReport
    Generate compliance report after applying settings

.EXAMPLE
    .\harden.ps1 -Level 2 -GenerateReport
#>

[CmdletBinding()]
param(
    [ValidateSet(1, 2)]
    [int]$Level = 1,
    
    [switch]$GenerateReport
)

# Ensure running as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    throw "This script must be run as Administrator"
}

$report = @()

function Apply-SecuritySetting {
    param(
        [string]$Name,
        [scriptblock]$Action,
        [int]$RequiredLevel = 1
    )
    
    if ($Level -ge $RequiredLevel) {
        Write-Host "Applying: $Name" -ForegroundColor Yellow
        try {
            & $Action
            $script:report += [PSCustomObject]@{
                Setting = $Name
                Status = "Applied"
                Level = $RequiredLevel
            }
            Write-Host "  [SUCCESS]" -ForegroundColor Green
        } catch {
            $script:report += [PSCustomObject]@{
                Setting = $Name
                Status = "Failed: $_"
                Level = $RequiredLevel
            }
            Write-Host "  [FAILED] $_" -ForegroundColor Red
        }
    }
}

Write-Host "Starting security hardening (Level $Level)..." -ForegroundColor Green
Write-Host ""

# Password Policy
Apply-SecuritySetting "Password Policy - Minimum Length" {
    net accounts /minpwlen:14
}

Apply-SecuritySetting "Password Policy - Password History" {
    net accounts /uniquepw:24
}

Apply-SecuritySetting "Password Policy - Maximum Age" {
    net accounts /maxpwage:60
}

# Account Lockout Policy
Apply-SecuritySetting "Account Lockout - Threshold" {
    net accounts /lockoutthreshold:5
}

Apply-SecuritySetting "Account Lockout - Duration" {
    net accounts /lockoutduration:30
}

# Audit Policy
Apply-SecuritySetting "Audit Policy - Logon Events" {
    auditpol /set /subcategory:"Logon" /success:enable /failure:enable
}

Apply-SecuritySetting "Audit Policy - Account Management" {
    auditpol /set /subcategory:"User Account Management" /success:enable /failure:enable
}

Apply-SecuritySetting "Audit Policy - Privilege Use" {
    auditpol /set /subcategory:"Sensitive Privilege Use" /success:enable /failure:enable
} -RequiredLevel 2

# Windows Firewall
Apply-SecuritySetting "Windows Firewall - Enable All Profiles" {
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
}

# Remote Desktop
Apply-SecuritySetting "Remote Desktop - Require NLA" {
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 1
} -RequiredLevel 2

# Windows Defender
Apply-SecuritySetting "Windows Defender - Real-time Protection" {
    Set-MpPreference -DisableRealtimeMonitoring $false
}

Apply-SecuritySetting "Windows Defender - Cloud Protection" {
    Set-MpPreference -MAPSReporting Advanced
} -RequiredLevel 2

# SMB Settings
Apply-SecuritySetting "SMB - Disable SMBv1" {
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
}

Apply-SecuritySetting "SMB - Require Signing" {
    Set-SmbServerConfiguration -RequireSecuritySignature $true -Force
} -RequiredLevel 2

# PowerShell Logging
Apply-SecuritySetting "PowerShell - Script Block Logging" {
    $basePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
    if (-not (Test-Path $basePath)) {
        New-Item -Path $basePath -Force | Out-Null
    }
    Set-ItemProperty -Path $basePath -Name "EnableScriptBlockLogging" -Value 1
} -RequiredLevel 2

# User Rights Assignment
Apply-SecuritySetting "User Rights - Deny log on through Remote Desktop" {
    # This would typically use secedit or group policy
    Write-Host "    Note: Configure via Group Policy" -ForegroundColor Cyan
} -RequiredLevel 2

# Generate Report
if ($GenerateReport) {
    Write-Host "\nGenerating compliance report..." -ForegroundColor Yellow
    $reportPath = "C:\SecurityReports\Hardening_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    
    # Create directory if needed
    $reportDir = Split-Path $reportPath -Parent
    if (-not (Test-Path $reportDir)) {
        New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
    }
    
    # Export report
    $report | Export-Csv -Path $reportPath -NoTypeInformation
    Write-Host "Report saved to: $reportPath" -ForegroundColor Green
    
    # Display summary
    $successCount = ($report | Where-Object Status -eq "Applied").Count
    $failCount = ($report | Where-Object Status -like "Failed*").Count
    
    Write-Host "\nSummary:" -ForegroundColor Cyan
    Write-Host "  Total Settings: $($report.Count)"
    Write-Host "  Successful: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $failCount" -ForegroundColor Red
}

Write-Host "\nSecurity hardening complete!" -ForegroundColor Green

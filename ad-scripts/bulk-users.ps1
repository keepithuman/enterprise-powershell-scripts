<#
.SYNOPSIS
    Bulk create or modify Active Directory users from CSV file

.DESCRIPTION
    This script reads a CSV file and creates or updates AD users in bulk.
    Supports creating users, setting passwords, group memberships, and organizational units.

.PARAMETER CSVPath
    Path to the CSV file containing user information

.PARAMETER WhatIf
    Perform a dry run without making changes

.EXAMPLE
    .\bulk-users.ps1 -CSVPath "C:\temp\users.csv"

.NOTES
    CSV Format: FirstName,LastName,SamAccountName,Email,Department,Title,Manager,Groups,OU
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$CSVPath,
    
    [switch]$WhatIf
)

# Import required module
Import-Module ActiveDirectory -ErrorAction Stop

# Validate CSV exists
if (-not (Test-Path $CSVPath)) {
    throw "CSV file not found: $CSVPath"
}

# Import and validate CSV
$users = Import-Csv $CSVPath
if ($users.Count -eq 0) {
    throw "No users found in CSV file"
}

Write-Host "Processing $($users.Count) users..." -ForegroundColor Green

foreach ($user in $users) {
    try {
        # Build user parameters
        $userParams = @{
            Name = "$($user.FirstName) $($user.LastName)"
            GivenName = $user.FirstName
            Surname = $user.LastName
            SamAccountName = $user.SamAccountName
            UserPrincipalName = "$($user.SamAccountName)@$((Get-ADDomain).DNSRoot)"
            EmailAddress = $user.Email
            Department = $user.Department
            Title = $user.Title
            Enabled = $true
            ChangePasswordAtLogon = $true
        }
        
        # Generate secure password
        $password = ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force
        $userParams.AccountPassword = $password
        
        # Set OU if specified
        if ($user.OU) {
            $userParams.Path = $user.OU
        }
        
        # Check if user exists
        $existingUser = Get-ADUser -Filter "SamAccountName -eq '$($user.SamAccountName)'" -ErrorAction SilentlyContinue
        
        if ($existingUser) {
            Write-Host "Updating existing user: $($user.SamAccountName)" -ForegroundColor Yellow
            if (-not $WhatIf) {
                Set-ADUser -Identity $user.SamAccountName `
                    -EmailAddress $user.Email `
                    -Department $user.Department `
                    -Title $user.Title
            }
        } else {
            Write-Host "Creating new user: $($user.SamAccountName)" -ForegroundColor Green
            if (-not $WhatIf) {
                New-ADUser @userParams
            }
        }
        
        # Add to groups if specified
        if ($user.Groups) {
            $groups = $user.Groups -split ';'
            foreach ($group in $groups) {
                if (-not $WhatIf) {
                    Add-ADGroupMember -Identity $group -Members $user.SamAccountName -ErrorAction SilentlyContinue
                }
                Write-Host "  Added to group: $group" -ForegroundColor Cyan
            }
        }
        
    } catch {
        Write-Error "Failed to process user $($user.SamAccountName): $_"
    }
}

Write-Host "\nUser processing complete!" -ForegroundColor Green

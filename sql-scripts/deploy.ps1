<#
.SYNOPSIS
    Deploy SQL Server database changes

.DESCRIPTION
    Executes SQL scripts for database deployment, including schema updates,
    stored procedures, and data migrations.

.PARAMETER Database
    Target database name

.PARAMETER Version
    Version number to deploy

.PARAMETER Server
    SQL Server instance (default: localhost)

.PARAMETER ScriptPath
    Path to SQL scripts directory

.EXAMPLE
    .\deploy.ps1 -Database "Production" -Version "2.5.0"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Database,
    
    [Parameter(Mandatory=$true)]
    [string]$Version,
    
    [string]$Server = "localhost",
    
    [string]$ScriptPath = "C:\SQLScripts"
)

# Function to execute SQL command
function Invoke-SqlCommand {
    param(
        [string]$Query,
        [string]$Database,
        [string]$Server
    )
    
    $connectionString = "Server=$Server;Database=$Database;Integrated Security=true;"
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $Query
        $command.CommandTimeout = 300
        $command.ExecuteNonQuery() | Out-Null
    } finally {
        $connection.Close()
    }
}

# Check if database exists
Write-Host "Checking database connection..." -ForegroundColor Yellow
$checkDb = @"
SELECT DB_ID('$Database')
"@

try {
    Invoke-SqlCommand -Query $checkDb -Database "master" -Server $Server
    Write-Host "Connected to database: $Database" -ForegroundColor Green
} catch {
    throw "Cannot connect to database: $_"
}

# Create version tracking table if not exists
$versionTable = @"
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DeploymentHistory')
BEGIN
    CREATE TABLE DeploymentHistory (
        Id INT IDENTITY(1,1) PRIMARY KEY,
        Version NVARCHAR(50) NOT NULL,
        DeployedDate DATETIME NOT NULL DEFAULT GETDATE(),
        DeployedBy NVARCHAR(100) NOT NULL DEFAULT SUSER_NAME(),
        Success BIT NOT NULL DEFAULT 1,
        Notes NVARCHAR(MAX)
    )
END
"@

Invoke-SqlCommand -Query $versionTable -Database $Database -Server $Server

# Check if version already deployed
$checkVersion = @"
SELECT COUNT(*) FROM DeploymentHistory WHERE Version = '$Version' AND Success = 1
"@

# Begin deployment
Write-Host "\nStarting deployment of version $Version..." -ForegroundColor Green

# Example deployment script
$deploymentScript = @"
-- Deployment Script for Version $Version
-- Generated: $(Get-Date)

BEGIN TRANSACTION

BEGIN TRY
    -- Example: Add new column
    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Users') AND name = 'LastModified')
    BEGIN
        ALTER TABLE dbo.Users ADD LastModified DATETIME NULL
        PRINT 'Added LastModified column to Users table'
    END
    
    -- Example: Create or update stored procedure
    IF OBJECT_ID('dbo.sp_GetUsersByDepartment', 'P') IS NOT NULL
        DROP PROCEDURE dbo.sp_GetUsersByDepartment
    
    CREATE PROCEDURE dbo.sp_GetUsersByDepartment
        @Department NVARCHAR(100)
    AS
    BEGIN
        SELECT * FROM dbo.Users WHERE Department = @Department
    END
    PRINT 'Created sp_GetUsersByDepartment'
    
    -- Record successful deployment
    INSERT INTO DeploymentHistory (Version, Notes)
    VALUES ('$Version', 'Deployment completed successfully')
    
    COMMIT TRANSACTION
    PRINT 'Deployment of version $Version completed successfully'
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION
    
    -- Record failed deployment
    INSERT INTO DeploymentHistory (Version, Success, Notes)
    VALUES ('$Version', 0, ERROR_MESSAGE())
    
    THROW
END CATCH
"@

try {
    # Execute deployment script
    Invoke-SqlCommand -Query $deploymentScript -Database $Database -Server $Server
    
    Write-Host "\nDeployment completed successfully!" -ForegroundColor Green
    Write-Host "Version $Version has been deployed to $Database" -ForegroundColor Cyan
    
    # Show deployment history
    Write-Host "\nRecent deployments:" -ForegroundColor Yellow
    $history = @"
    SELECT TOP 5 Version, DeployedDate, DeployedBy, Success
    FROM DeploymentHistory
    ORDER BY DeployedDate DESC
"@
    
} catch {
    Write-Error "Deployment failed: $_"
    throw
}

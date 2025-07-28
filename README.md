# Enterprise PowerShell Scripts

A collection of production-ready PowerShell scripts for enterprise automation tasks. These scripts are designed to be used with the [ansible-powershell-github-executor](https://github.com/keepithuman/ansible-powershell-github-executor) Ansible role.

## Scripts Included

### 1. Active Directory Management
- `ad-scripts/bulk-users.ps1` - Bulk create/modify AD users from CSV

### 2. IIS Web Server Configuration  
- `iis-scripts/setup-site.ps1` - Configure IIS sites and application pools

### 3. SQL Server Deployment
- `sql-scripts/deploy.ps1` - Deploy database changes and migrations

### 4. Office 365 Management
- `o365-scripts/mailbox-setup.ps1` - Create and configure O365 mailboxes

### 5. Security Hardening
- `security/harden.ps1` - Apply security baselines and CIS benchmarks

### 6. Application Deployment
- `deploy/deploy-app.ps1` - Deploy .NET applications to IIS

### 7. Disaster Recovery
- `dr/validate.ps1` - Validate DR readiness and test failover

### 8. Developer Environment Setup
- `dev-setup/install.ps1` - Install and configure developer tools

## Usage

These scripts are designed to be executed via Ansible using the ansible-powershell-github-executor role:

```yaml
- hosts: windows_servers
  roles:
    - role: ansible-powershell-github-executor
      vars:
        powershell_script_url: "https://raw.githubusercontent.com/keepithuman/enterprise-powershell-scripts/main/ad-scripts/bulk-users.ps1"
        powershell_script_args: "-CSVPath 'C:\\temp\\users.csv'"
```

## Security Notes

- Always use HTTPS URLs when downloading scripts
- Enable checksum verification for production use
- Review scripts before execution
- Use appropriate execution policies

## License

MIT

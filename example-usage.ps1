# Azure VM Cloning - Usage Examples

This file contains common usage examples and scenarios for the Azure VM cloning script.

## Basic Usage

### 1. Simple VM Cloning
```powershell
# Clone a VM with interactive prompts
.\create-vm-from-snapshot.ps1
```

### 2. Environment Validation First
```powershell
# Always recommended to run environment test first
.\test-azure-environment.ps1

# Then run the cloning script
.\create-vm-from-snapshot.ps1
```

## Advanced Scenarios

### 3. Development Environment Setup
```powershell
# Example workflow for setting up dev environments:

# 1. Test environment
.\test-azure-environment.ps1

# 2. Clone production VM to dev
.\create-vm-from-snapshot.ps1
# Select production VM as source
# Use smaller VM size (e.g., Standard_B2s) for cost savings
# Choose "Create new NSG with hardened rules" for security
```

### 4. Disaster Recovery Testing
```powershell
# Clone critical VMs for DR testing:

# 1. Validate environment
.\test-azure-environment.ps1

# 2. Clone critical VM
.\create-vm-from-snapshot.ps1
# Select critical production VM
# Use same VM size as source
# Choose "Copy source NSG rules" to maintain same security posture
```

### 5. Training Environment Creation
```powershell
# Create training VMs from a master template:

# 1. Test connectivity
.\test-azure-environment.ps1

# 2. Clone master training VM
.\create-vm-from-snapshot.ps1
# Select master training VM
# Use cost-effective VM size (Standard_B2ms)
# Create new hardened NSG for training isolation
```

## Best Practices Examples

### 6. Cost-Optimized Cloning
```powershell
# For cost-conscious environments:

# During VM cloning:
# - Choose smaller VM sizes (B-series for burstable workloads)
# - Reuse existing boot diagnostics storage accounts
# - Delete snapshots after successful deployment
# - Use Standard_LRS disks unless performance is critical
```

### 7. Security-Focused Cloning
```powershell
# For security-critical environments:

# During VM cloning:
# - Always choose "Create new NSG with hardened rules"
# - Upgrade to Premium_LRS disks when prompted
# - Keep snapshots for audit trail
# - Use proper naming conventions for traceability
```

### 8. Cross-Resource Group Scenarios
```powershell
# When VNet is in different resource group:

# The script automatically handles this scenario:
# - Detects cross-RG VNet configuration
# - Validates permissions to VNet resource group
# - Creates VM in source RG but connects to cross-RG VNet
# - Provides detailed logging of network configuration
```

## Common Workflows

### 9. Weekly Dev Environment Refresh
```powershell
# Automated weekly refresh workflow:

# 1. Validate environment (can be automated in CI/CD)
.\test-azure-environment.ps1

# 2. Remove old dev VMs (manual or scripted)
# Remove-AzVM -ResourceGroupName "dev-rg" -Name "old-dev-vm" -Force

# 3. Clone fresh from production
.\create-vm-from-snapshot.ps1
# Select production VM
# Use dev-appropriate VM size
# Reuse storage accounts for cost efficiency
```

### 10. Multi-VM Environment Cloning
```powershell
# For cloning multiple related VMs:

# Clone each VM individually with consistent naming:
# VM1: web-server-prod → web-server-dev
# VM2: db-server-prod → db-server-dev
# VM3: app-server-prod → app-server-dev

# Run for each VM:
.\create-vm-from-snapshot.ps1
```

## Troubleshooting Examples

### 11. Permission Issues
```powershell
# If you encounter permission errors:

# 1. Check current context
Get-AzContext

# 2. Switch subscription if needed
Select-AzSubscription -SubscriptionId "your-subscription-id"

# 3. Validate permissions
.\test-azure-environment.ps1

# 4. If still failing, contact Azure admin for:
# - Contributor role on subscription
# - Network Contributor on VNet resource group
```

### 12. Module Issues
```powershell
# If Azure modules are missing or outdated:

# 1. Check installed modules
Get-Module -Name Az.* -ListAvailable

# 2. Install required modules
Install-Module -Name Az.Accounts, Az.Compute, Az.Resources, Az.Network -Force

# 3. Update if needed
Update-Module -Name Az.Accounts, Az.Compute, Az.Resources, Az.Network

# 4. Re-test environment
.\test-azure-environment.ps1
```

## Performance Optimization

### 13. Large VM Cloning
```powershell
# For VMs with large disks (>1TB):

# - Ensure sufficient quota in target region
# - Consider Premium_LRS for better performance
# - Plan for longer snapshot creation time
# - Monitor costs during cloning process
```

### 14. Batch Operations
```powershell
# For cloning multiple VMs efficiently:

# 1. Run environment test once
.\test-azure-environment.ps1

# 2. Clone VMs in sequence (parallel not recommended)
# 3. Use consistent naming and tagging
# 4. Monitor resource group limits
# 5. Clean up snapshots after successful deployments
```

## Integration Examples

### 15. CI/CD Pipeline Integration
```powershell
# PowerShell script for automated pipeline:

# pipeline-vm-clone.ps1
param(
    [string]$SourceVMName,
    [string]$NewVMName,
    [string]$ResourceGroupName
)

# Validate environment
$testResult = .\test-azure-environment.ps1
if (-not $testResult) {
    throw "Environment validation failed"
}

# Note: For CI/CD, you'd need to modify the main script
# to accept parameters instead of interactive input
```

### 16. Monitoring Integration
```powershell
# Add monitoring after VM creation:

# After running create-vm-from-snapshot.ps1:
# 1. Configure monitoring agents
# 2. Set up backup policies
# 3. Configure alerts
# 4. Tag resources for cost tracking
```

## Cleanup Examples

### 17. Resource Cleanup
```powershell
# Cleanup after testing:

# Remove test VMs
Remove-AzVM -ResourceGroupName "test-rg" -Name "test-vm" -Force

# Remove associated NICs
Remove-AzNetworkInterface -ResourceGroupName "test-rg" -Name "test-vm-nic" -Force

# Remove NSGs if created specifically for test
Remove-AzNetworkSecurityGroup -ResourceGroupName "test-rg" -Name "test-vm-nsg" -Force

# Clean up old snapshots
Remove-AzSnapshot -ResourceGroupName "test-rg" -SnapshotName "old-snapshot" -Force
```

### 18. Cost Management
```powershell
# Regular cost optimization:

# 1. Review and remove unused snapshots older than 30 days
Get-AzSnapshot | Where-Object {$_.TimeCreated -lt (Get-Date).AddDays(-30)} | Remove-AzSnapshot -Force

# 2. Review boot diagnostics storage usage
Get-AzStorageAccount | Where-Object {$_.StorageAccountName -like "*bootdiag*"}

# 3. Monitor VM usage and resize if needed
# Use Azure Cost Management + Billing portal for detailed analysis
```

---

## 📝 Notes

- Always run `.\test-azure-environment.ps1` before cloning operations
- Keep snapshots only as long as needed for cost optimization
- Use appropriate VM sizes based on workload requirements
- Follow your organization's naming conventions and tagging policies
- Regular cleanup of test resources to manage costs

## 🔗 Additional Resources

- [Azure VM Sizing Guide](https://docs.microsoft.com/en-us/azure/virtual-machines/sizes)
- [Azure Cost Management](https://docs.microsoft.com/en-us/azure/cost-management-billing/)
- [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/writing-portable-modules)

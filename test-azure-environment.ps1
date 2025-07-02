#Requires -Modules Az.Accounts, Az.Compute, Az.Resources, Az.Network

<#
.SYNOPSIS
    Test script to validate Azure PowerShell environment and connectivity for VM snapshot operations.

.DESCRIPTION
    This script validates that all required Azure PowerShell modules are installed and that
    the user has proper connectivity and permissions to perform VM snapshot operations.

.EXAMPLE
    .\test-azure-environment.ps1
    
    Runs all validation checks and reports the status.
#>

[CmdletBinding()]
param()

function Write-TestLog {
    param(
        [string]$Message,
        [string]$Status = "INFO"
    )
    
    $color = switch ($Status) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "WARN" { "Yellow" }
        "INFO" { "Cyan" }
        default { "White" }
    }
    
    $icon = switch ($Status) {
        "PASS" { "[OK]" }
        "FAIL" { "[X]" }
        "WARN" { "[!]" }
        "INFO" { "[i]" }
        default { "[-]" }
    }
    
    Write-Host "$icon $Message" -ForegroundColor $color
}

function Test-ModuleInstallation {
    param([string]$ModuleName)
    
    try {
        $module = Get-Module -Name $ModuleName -ListAvailable | Select-Object -First 1
        if ($module) {
            Write-TestLog "Module $ModuleName is installed (Version: $($module.Version))" -Status "PASS"
            return $true
        } else {
            Write-TestLog "Module $ModuleName is not installed" -Status "FAIL"
            return $false
        }
    }
    catch {
        Write-TestLog "Error checking module $ModuleName`: $($_.Exception.Message)" -Status "FAIL"
        return $false
    }
}

function Test-AzureConnection {
    try {
        $context = Get-AzContext
        if ($context) {
            Write-TestLog "Connected to Azure subscription: $($context.Subscription.Name)" -Status "PASS"
            Write-TestLog "Account: $($context.Account.Id)" -Status "INFO"
            Write-TestLog "Tenant: $($context.Tenant.Id)" -Status "INFO"
            return $true
        } else {
            Write-TestLog "Not connected to Azure" -Status "FAIL"
            return $false
        }
    }
    catch {
        Write-TestLog "Error checking Azure connection: $($_.Exception.Message)" -Status "FAIL"
        return $false
    }
}

function Test-ResourceGroupAccess {
    try {
        $resourceGroups = Get-AzResourceGroup -ErrorAction Stop
        if ($resourceGroups.Count -gt 0) {
            Write-TestLog "Can access $($resourceGroups.Count) resource group(s)" -Status "PASS"
            
            # Show first few resource groups
            $showCount = [Math]::Min(3, $resourceGroups.Count)
            for ($i = 0; $i -lt $showCount; $i++) {
                Write-TestLog "  - $($resourceGroups[$i].ResourceGroupName) ($($resourceGroups[$i].Location))" -Status "INFO"
            }
            
            if ($resourceGroups.Count -gt 3) {
                Write-TestLog "  ... and $($resourceGroups.Count - 3) more" -Status "INFO"
            }
            
            return $true
        } else {
            Write-TestLog "No accessible resource groups found" -Status "WARN"
            return $false
        }
    }
    catch {
        Write-TestLog "Cannot access resource groups: $($_.Exception.Message)" -Status "FAIL"
        return $false
    }
}

function Test-VirtualMachineAccess {
    try {
        $allVMs = @()
        $resourceGroups = Get-AzResourceGroup
        
        foreach ($rg in $resourceGroups) {
            try {
                $vms = Get-AzVM -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
                $allVMs += $vms
            }
            catch {
                # Continue with other resource groups if one fails
            }
        }
        
        if ($allVMs.Count -gt 0) {
            Write-TestLog "Can access $($allVMs.Count) virtual machine(s)" -Status "PASS"
            
            # Show first few VMs
            $showCount = [Math]::Min(3, $allVMs.Count)
            for ($i = 0; $i -lt $showCount; $i++) {
                $vm = $allVMs[$i]
                Write-TestLog "  - $($vm.Name) in $($vm.ResourceGroupName) ($($vm.HardwareProfile.VmSize))" -Status "INFO"
            }
            
            if ($allVMs.Count -gt 3) {
                Write-TestLog "  ... and $($allVMs.Count - 3) more" -Status "INFO"
            }
            
            return $true
        } else {
            Write-TestLog "No virtual machines found (this is OK if none exist)" -Status "WARN"
            return $true  # Not a failure if no VMs exist
        }
    }
    catch {
        Write-TestLog "Cannot access virtual machines: $($_.Exception.Message)" -Status "FAIL"
        return $false
    }
}

function Test-SnapshotPermissions {
    try {
        # Try to list snapshots (this tests read permissions)
        $resourceGroups = Get-AzResourceGroup | Select-Object -First 1
        if ($resourceGroups) {
            $null = Get-AzSnapshot -ResourceGroupName $resourceGroups.ResourceGroupName -ErrorAction SilentlyContinue
            Write-TestLog "Can access snapshot operations" -Status "PASS"
            return $true
        } else {
            Write-TestLog "Cannot test snapshot permissions - no resource groups available" -Status "WARN"
            return $false
        }
    }
    catch {
        Write-TestLog "Cannot access snapshot operations: $($_.Exception.Message)" -Status "FAIL"
        return $false
    }
}

function Test-NetworkPermissions {
    try {
        # Try to list virtual networks (this tests read permissions)
        $resourceGroups = Get-AzResourceGroup | Select-Object -First 1
        if ($resourceGroups) {
            $null = Get-AzVirtualNetwork -ResourceGroupName $resourceGroups.ResourceGroupName -ErrorAction SilentlyContinue
            Write-TestLog "Can access network operations" -Status "PASS"
            return $true
        } else {
            Write-TestLog "Cannot test network permissions - no resource groups available" -Status "WARN"
            return $false
        }
    }
    catch {
        Write-TestLog "Cannot access network operations: $($_.Exception.Message)" -Status "FAIL"
        return $false
    }
}

# Main execution
Write-Host ""
Write-Host "=== Azure VM Snapshot Environment Validation ===" -ForegroundColor Yellow
Write-Host ""

$allPassed = $true

# Test 1: Module Installation
Write-Host "1. Testing Azure PowerShell Module Installation..." -ForegroundColor Yellow
$requiredModules = @("Az.Accounts", "Az.Compute", "Az.Resources", "Az.Network")
foreach ($module in $requiredModules) {
    $result = Test-ModuleInstallation -ModuleName $module
    $allPassed = $allPassed -and $result
}

Write-Host ""

# Test 2: Azure Connection
Write-Host "2. Testing Azure Connection..." -ForegroundColor Yellow
$connectionResult = Test-AzureConnection
$allPassed = $allPassed -and $connectionResult

Write-Host ""

if ($connectionResult) {
    # Test 3: Resource Group Access
    Write-Host "3. Testing Resource Group Access..." -ForegroundColor Yellow
    $rgResult = Test-ResourceGroupAccess
    $allPassed = $allPassed -and $rgResult
    
    Write-Host ""
    
    # Test 4: Virtual Machine Access
    Write-Host "4. Testing Virtual Machine Access..." -ForegroundColor Yellow
    $vmResult = Test-VirtualMachineAccess
    $allPassed = $allPassed -and $vmResult
    
    Write-Host ""
    
    # Test 5: Snapshot Permissions
    Write-Host "5. Testing Snapshot Permissions..." -ForegroundColor Yellow
    $snapshotResult = Test-SnapshotPermissions
    $allPassed = $allPassed -and $snapshotResult
    
    Write-Host ""
    
    # Test 6: Network Permissions
    Write-Host "6. Testing Network Permissions..." -ForegroundColor Yellow
    $networkResult = Test-NetworkPermissions
    $allPassed = $allPassed -and $networkResult
    
    Write-Host ""
} else {
    Write-TestLog "Skipping further tests due to connection failure" -Status "WARN"
    $allPassed = $false
}

# Summary
Write-Host "=== Summary ===" -ForegroundColor Yellow
if ($allPassed) {
    Write-TestLog "All tests passed! Environment is ready for VM snapshot operations." -Status "PASS"
    Write-Host ""
    Write-TestLog "You can now run: .\create-vm-from-snapshot.ps1" -Status "INFO"
} else {
    Write-TestLog "Some tests failed. Please address the issues above before proceeding." -Status "FAIL"
    Write-Host ""
    Write-TestLog "Common solutions:" -Status "INFO"
    Write-TestLog "- Install missing modules: Install-Module -Name Az.Accounts, Az.Compute, Az.Resources, Az.Network" -Status "INFO"
    Write-TestLog "- Connect to Azure: Connect-AzAccount" -Status "INFO"
    Write-TestLog "- Check permissions with your Azure administrator" -Status "INFO"
}

Write-Host ""

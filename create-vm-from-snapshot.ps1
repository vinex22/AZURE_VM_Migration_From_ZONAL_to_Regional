#Requires -Modules Az.Accounts, Az.Compute, Az.Resources, Az.Network
#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Create a new Azure VM by snapshotting an existing VM's OS disk
    
.DESCRIPTION
    This script performs the following steps:
    1. Prompts for source VM resource group and name
    2. Finds the OS disk of the existing VM
    3. Creates a snapshot of the OS disk
    4. Creates a new managed disk from the snapshot
    5. Creates a new VM using the new disk in the same RG and VNet
    
.NOTES
    Author: vinayjain@microsoft.com
    Version: 2.4 - Microsoft Branded
    
    Prerequisites:
    - Azure PowerShell module installed
    - User authenticated to Azure (Connect-AzAccount)
    - Contributor permissions on subscription
    - Source VM can remain running (snapshot is taken while VM is online)
    
.EXAMPLE
    .\create-vm-from-snapshot.ps1
    
    The script will interactively prompt for:
    - Source VM Resource Group
    - Source VM Name
    - New VM Name
    - VM Size for new VM
#>

[CmdletBinding()]
param()

# Error handling and logging functions
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $levelColor = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "INPUT" { "Cyan" }
        "HEADER" { "Magenta" }
        "STEP" { "Blue" }
        "DETAIL" { "Gray" }
        default { "White" }
    }
    
    $levelIcon = switch ($Level) {
        "ERROR" { "❌" }
        "WARN" { "⚠️ " }
        "SUCCESS" { "✅" }
        "INPUT" { "🔧" }
        "HEADER" { "🚀" }
        "STEP" { "📋" }
        "DETAIL" { "📝" }
        default { "ℹ️ " }
    }
    
    Write-Host "[$timestamp] [$levelIcon $Level] $Message" -ForegroundColor $levelColor
}

function Show-MicrosoftHeader {
    Write-Host ""
    Write-Host "███╗   ███╗██╗ ██████╗██████╗  ██████╗ ███████╗ ██████╗ ███████╗████████╗" -ForegroundColor Blue
    Write-Host "████╗ ████║██║██╔════╝██╔══██╗██╔═══██╗██╔════╝██╔═══██╗██╔════╝╚══██╔══╝" -ForegroundColor Blue
    Write-Host "██╔████╔██║██║██║     ██████╔╝██║   ██║███████╗██║   ██║█████╗     ██║   " -ForegroundColor Blue
    Write-Host "██║╚██╔╝██║██║██║     ██╔══██╗██║   ██║╚════██║██║   ██║██╔══╝     ██║   " -ForegroundColor Blue
    Write-Host "██║ ╚═╝ ██║██║╚██████╗██║  ██║╚██████╔╝███████║╚██████╔╝██║        ██║   " -ForegroundColor Blue
    Write-Host "╚═╝     ╚═╝╚═╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝        ╚═╝   " -ForegroundColor Blue
    Write-Host ""
    Write-Host "            🔄 AZURE VM CLONING AUTOMATION 🔄" -ForegroundColor White -BackgroundColor Blue
    Write-Host "                Powered by PowerShell & Azure  " -ForegroundColor DarkBlue
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "        Fast • Reliable • Secure VM Cloning by Microsoft Azure        " -ForegroundColor Gray
    Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-ProgressBar {
    param([int]$Step, [int]$TotalSteps, [string]$Activity)
    
    $percentage = [math]::Round(($Step / $TotalSteps) * 100)
    $completed = [math]::Round($percentage / 5)
    $remaining = 20 - $completed
    
    $progressBar = "▓" * $completed + "░" * $remaining
    
    Write-Host ""
    Write-Host "Microsoft Progress: [$progressBar] $percentage% - $Activity" -ForegroundColor Blue
    Write-Host ""
}

function Test-AzureConnection {
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Log "Not connected to Azure. Please run Connect-AzAccount first." -Level "ERROR"
            exit 1
        }
        Write-Log "Connected to Azure subscription: $($context.Subscription.Name)" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Error checking Azure connection: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Get-UserInput {
    param(
        [string]$Prompt,
        [string]$DefaultValue = "",
        [bool]$Required = $true
    )
    
    do {
        if ($DefaultValue) {
            $userInput = Read-Host "$Prompt [$DefaultValue]"
            if ([string]::IsNullOrWhiteSpace($userInput)) {
                $userInput = $DefaultValue
            }
        } else {
            $userInput = Read-Host $Prompt
        }
        
        if ($Required -and [string]::IsNullOrWhiteSpace($userInput)) {
            Write-Log "This field is required. Please provide a value." -Level "WARN"
        }
    } while ($Required -and [string]::IsNullOrWhiteSpace($userInput))
    
    return $userInput.Trim()
}

function Show-VMList {
    param([string]$ResourceGroupName)
    
    try {
        $vms = Get-AzVM -ResourceGroupName $ResourceGroupName
        if ($vms.Count -eq 0) {
            Write-Log "No VMs found in resource group '$ResourceGroupName'" -Level "WARN"
            return $null
        }
        
        Write-Log "Available VMs in resource group '$ResourceGroupName':" -Level "STEP"
        Write-Host "┌────┬─────────────────────┬────────────────────┬──────────────────┐" -ForegroundColor DarkGray
        Write-Host "│ #  │ VM Name             │ Size               │ Status           │" -ForegroundColor DarkGray
        Write-Host "├────┼─────────────────────┼────────────────────┼──────────────────┤" -ForegroundColor DarkGray
        
        for ($i = 0; $i -lt $vms.Count; $i++) {
            $vm = $vms[$i]
            $status = (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vm.Name -Status).Statuses | Where-Object {$_.Code -like "PowerState/*"}
            $statusColor = if ($status.DisplayStatus -eq "VM running") { "Green" } else { "Yellow" }
            
            $num = ($i + 1).ToString().PadLeft(2)
            $name = $vm.Name.PadRight(19).Substring(0,19)
            $size = $vm.HardwareProfile.VmSize.PadRight(18).Substring(0,18)
            $stat = $status.DisplayStatus.PadRight(16).Substring(0,16)
            
            Write-Host "│ $num │ $name │ $size │ " -ForegroundColor DarkGray -NoNewline
            Write-Host "$stat" -ForegroundColor $statusColor -NoNewline
            Write-Host " │" -ForegroundColor DarkGray
        }
        
        Write-Host "└────┴─────────────────────┴────────────────────┴──────────────────┘" -ForegroundColor DarkGray
        
        return $vms
    }
    catch {
        Write-Log "Error listing VMs: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

# Main script execution
try {
    Show-MicrosoftHeader
    
    Write-Log "Fast, reliable VM cloning powered by Azure snapshots and disk technology" -Level "HEADER"
    Write-Log "Features: Cross-RG VNet support, NSG options, security best practices" -Level "DETAIL"
    
    Show-ProgressBar -Step 0 -TotalSteps 9 -Activity "Initializing Azure Connection"
    
    # Validate Azure connection
    if (-not (Test-AzureConnection)) {
        exit 1
    }
    
    # Step 1: Get source VM information
    Show-ProgressBar -Step 1 -TotalSteps 9 -Activity "Getting Source VM Information"
    Write-Log "Step 1: Getting source VM information..." -Level "STEP"
    
    # List available resource groups
    Write-Log "Available Resource Groups:" -Level "HEADER"
    $resourceGroups = Get-AzResourceGroup | Sort-Object ResourceGroupName
    
    Write-Host "┌────┬──────────────────────────────┬────────────────┐" -ForegroundColor DarkGray
    Write-Host "│ #  │ Resource Group Name          │ Location       │" -ForegroundColor DarkGray
    Write-Host "├────┼──────────────────────────────┼────────────────┤" -ForegroundColor DarkGray
    
    for ($i = 0; $i -lt $resourceGroups.Count; $i++) {
        $num = ($i + 1).ToString().PadLeft(2)
        $rgName = $resourceGroups[$i].ResourceGroupName.PadRight(28).Substring(0,28)
        $location = $resourceGroups[$i].Location.PadRight(14).Substring(0,14)
        Write-Host "│ $num │ $rgName │ $location │" -ForegroundColor White
    }
    Write-Host "└────┴──────────────────────────────┴────────────────┘" -ForegroundColor DarkGray
    
    $sourceRGName = Get-UserInput -Prompt "Enter the Resource Group name of the source VM" -Required $true
    
    # Validate resource group exists
    $sourceRG = Get-AzResourceGroup -Name $sourceRGName -ErrorAction SilentlyContinue
    if (-not $sourceRG) {
        Write-Log "Resource group '$sourceRGName' not found!" -Level "ERROR"
        exit 1
    }
    
    Write-Log "Using resource group: $sourceRGName (Location: $($sourceRG.Location))" -Level "SUCCESS"
    
    # Show available VMs in the resource group
    $vms = Show-VMList -ResourceGroupName $sourceRGName
    if (-not $vms) {
        exit 1
    }
    
    $sourceVMName = Get-UserInput -Prompt "Enter the name of the source VM" -Required $true
    
    # Get source VM details
    $sourceVM = Get-AzVM -ResourceGroupName $sourceRGName -Name $sourceVMName -ErrorAction SilentlyContinue
    if (-not $sourceVM) {
        Write-Log "VM '$sourceVMName' not found in resource group '$sourceRGName'!" -Level "ERROR"
        exit 1
    }
    
    Write-Log "Found source VM: $($sourceVM.Name)" -Level "SUCCESS"
    Write-Host "┌─────────────────┬──────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "│ Property        │ Value                            │" -ForegroundColor DarkGray
    Write-Host "├─────────────────┼──────────────────────────────────┤" -ForegroundColor DarkGray
    Write-Host "│ VM Size         │ " -ForegroundColor DarkGray -NoNewline
    Write-Host "$($sourceVM.HardwareProfile.VmSize)".PadRight(32) -ForegroundColor Green -NoNewline
    Write-Host " │" -ForegroundColor DarkGray
    Write-Host "│ OS Type         │ " -ForegroundColor DarkGray -NoNewline
    Write-Host "$($sourceVM.StorageProfile.OsDisk.OsType)".PadRight(32) -ForegroundColor Cyan -NoNewline
    Write-Host " │" -ForegroundColor DarkGray
    Write-Host "│ Location        │ " -ForegroundColor DarkGray -NoNewline
    Write-Host "$($sourceVM.Location)".PadRight(32) -ForegroundColor Yellow -NoNewline
    Write-Host " │" -ForegroundColor DarkGray
    Write-Host "└─────────────────┴──────────────────────────────────┘" -ForegroundColor DarkGray
    
    # Step 2: Get OS disk information
    Show-ProgressBar -Step 2 -TotalSteps 9 -Activity "Analyzing OS Disk"
    Write-Log "Step 2: Getting OS disk information..." -Level "STEP"
    
    $osDiskName = $sourceVM.StorageProfile.OsDisk.Name
    $osDisk = Get-AzDisk -ResourceGroupName $sourceRGName -DiskName $osDiskName
    
    Write-Log "Found OS disk: $($osDisk.Name)" -Level "SUCCESS"
    Write-Host "┌─────────────────┬──────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "│ Disk Property   │ Value                            │" -ForegroundColor DarkGray
    Write-Host "├─────────────────┼──────────────────────────────────┤" -ForegroundColor DarkGray
    Write-Host "│ Disk Size       │ " -ForegroundColor DarkGray -NoNewline
    Write-Host "$($osDisk.DiskSizeGB) GB".PadRight(32) -ForegroundColor Green -NoNewline
    Write-Host " │" -ForegroundColor DarkGray
    Write-Host "│ Disk SKU        │ " -ForegroundColor DarkGray -NoNewline
    Write-Host "$($osDisk.Sku.Name)".PadRight(32) -ForegroundColor Cyan -NoNewline
    Write-Host " │" -ForegroundColor DarkGray
    Write-Host "│ Disk State      │ " -ForegroundColor DarkGray -NoNewline
    $diskStateColor = if ($osDisk.DiskState -eq "Attached") { "Green" } else { "Yellow" }
    Write-Host "$($osDisk.DiskState)".PadRight(32) -ForegroundColor $diskStateColor -NoNewline
    Write-Host " │" -ForegroundColor DarkGray
    Write-Host "└─────────────────┴──────────────────────────────────┘" -ForegroundColor DarkGray
    
    # Step 3: Get new VM details
    Show-ProgressBar -Step 3 -TotalSteps 9 -Activity "Configuring New VM"
    Write-Log "Step 3: Configuring new VM..." -Level "STEP"
    
    $newVMName = Get-UserInput -Prompt "Enter the name for the new VM" -Required $true
    
    # Check if VM name already exists
    $existingVM = Get-AzVM -ResourceGroupName $sourceRGName -Name $newVMName -ErrorAction SilentlyContinue
    if ($existingVM) {
        Write-Log "VM with name '$newVMName' already exists in this resource group!" -Level "ERROR"
        exit 1
    }
    
    # Suggest VM sizes
    Write-Log "Suggested VM sizes:" -Level "HEADER"
    $suggestedSizes = @("Standard_B2s", "Standard_B2ms", "Standard_D2s_v3", "Standard_D4s_v3", $sourceVM.HardwareProfile.VmSize)
    $uniqueSizes = $suggestedSizes | Sort-Object | Get-Unique
    
    Write-Host "┌────┬──────────────────┬─────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "│ #  │ VM Size          │ Description                 │" -ForegroundColor DarkGray
    Write-Host "├────┼──────────────────┼─────────────────────────────┤" -ForegroundColor DarkGray
    
    $sizeDescriptions = @{
        "Standard_B2s" = "2 vCPU, 4GB RAM (Burstable)"
        "Standard_B2ms" = "2 vCPU, 8GB RAM (Burstable)"
        "Standard_D2s_v3" = "2 vCPU, 8GB RAM (General Purpose)"
        "Standard_D4s_v3" = "4 vCPU, 16GB RAM (General Purpose)"
    }
    
    for ($i = 0; $i -lt $uniqueSizes.Count; $i++) {
        $size = $uniqueSizes[$i]
        $num = ($i + 1).ToString().PadLeft(2)
        $sizeName = $size.PadRight(16).Substring(0,16)
        $description = if ($sizeDescriptions[$size]) { $sizeDescriptions[$size] } else { "Custom/Premium size" }
        $desc = $description.PadRight(27).Substring(0,27)
        
        $sizeColor = if ($size -eq $sourceVM.HardwareProfile.VmSize) { "Yellow" } else { "White" }
        
        Write-Host "│ $num │ " -ForegroundColor DarkGray -NoNewline
        Write-Host "$sizeName" -ForegroundColor $sizeColor -NoNewline
        Write-Host " │ $desc │" -ForegroundColor DarkGray
    }
    Write-Host "└────┴──────────────────┴─────────────────────────────┘" -ForegroundColor DarkGray
    
    $newVMSize = Get-UserInput -Prompt "Enter VM size for the new VM" -DefaultValue $sourceVM.HardwareProfile.VmSize -Required $true
    
    # Step 4: Generate unique names for snapshot and new disk
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $snapshotName = "$osDiskName-snapshot-$timestamp"
    $newDiskName = "$newVMName-osdisk"
    
    Write-Log "Configuration Summary:" -Level "HEADER"
    Write-Host "┌─────────────────┬──────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "│ Configuration   │ Value                            │" -ForegroundColor DarkGray
    Write-Host "├─────────────────┼──────────────────────────────────┤" -ForegroundColor DarkGray
    Write-Host "│ Source VM       │ " -ForegroundColor DarkGray -NoNewline
    Write-Host "$sourceVMName".PadRight(32) -ForegroundColor Green -NoNewline
    Write-Host " │" -ForegroundColor DarkGray
    Write-Host "│ New VM          │ " -ForegroundColor DarkGray -NoNewline
    Write-Host "$newVMName".PadRight(32) -ForegroundColor Cyan -NoNewline
    Write-Host " │" -ForegroundColor DarkGray
    Write-Host "│ VM Size         │ " -ForegroundColor DarkGray -NoNewline
    Write-Host "$newVMSize".PadRight(32) -ForegroundColor Yellow -NoNewline
    Write-Host " │" -ForegroundColor DarkGray
    Write-Host "│ Snapshot        │ " -ForegroundColor DarkGray -NoNewline
    Write-Host "$snapshotName".Substring(0, [math]::Min(32, $snapshotName.Length)).PadRight(32) -ForegroundColor Magenta -NoNewline
    Write-Host " │" -ForegroundColor DarkGray
    Write-Host "│ New Disk        │ " -ForegroundColor DarkGray -NoNewline
    Write-Host "$newDiskName".PadRight(32) -ForegroundColor Blue -NoNewline
    Write-Host " │" -ForegroundColor DarkGray
    Write-Host "└─────────────────┴──────────────────────────────────┘" -ForegroundColor DarkGray
    
    $confirm = Get-UserInput -Prompt "Proceed with VM creation? (y/N)" -DefaultValue "N" -Required $false
    if ($confirm.ToLower() -ne "y" -and $confirm.ToLower() -ne "yes") {
        Write-Log "Operation cancelled by user." -Level "WARN"
        exit 0
    }
    
    # Step 5: Create snapshot
    Show-ProgressBar -Step 4 -TotalSteps 9 -Activity "Creating OS Disk Snapshot"
    Write-Log "Step 4: Creating snapshot of OS disk..." -Level "STEP"
    Write-Log "📸 This may take several minutes..." -Level "DETAIL"
    
    $snapshotConfig = New-AzSnapshotConfig `
        -SourceUri $osDisk.Id `
        -Location $sourceVM.Location `
        -CreateOption "Copy" `
        -SkuName "Standard_LRS"
    
    $snapshot = New-AzSnapshot `
        -ResourceGroupName $sourceRGName `
        -SnapshotName $snapshotName `
        -Snapshot $snapshotConfig
    
    Write-Log "Snapshot created successfully: $($snapshot.Name)" -Level "SUCCESS"
    
    # Step 6: Create new disk from snapshot
    Show-ProgressBar -Step 5 -TotalSteps 9 -Activity "Creating New Managed Disk"
    Write-Log "Step 5: Creating new disk from snapshot..." -Level "STEP"
    
    # Use same or better SKU for new disk (best practice)
    $newDiskSku = $osDisk.Sku.Name
    if ($osDisk.Sku.Name -eq "Standard_LRS") {
        Write-Log "Source disk uses Standard_LRS. Consider upgrading to Premium_LRS for better performance." -Level "DETAIL"
        $upgradeResponse = Get-UserInput -Prompt "⚡ Upgrade to Premium_LRS for better performance? (y/N)" -DefaultValue "N" -Required $false
        if ($upgradeResponse.ToLower() -eq "y" -or $upgradeResponse.ToLower() -eq "yes") {
            $newDiskSku = "Premium_LRS"
            Write-Log "Upgrading disk to Premium_LRS" -Level "SUCCESS"
        }
    }
    
    $newDiskConfig = New-AzDiskConfig `
        -Location $sourceVM.Location `
        -SourceResourceId $snapshot.Id `
        -CreateOption "Copy" `
        -SkuName $newDiskSku `
        -Tag @{
            "SourceVM" = $sourceVMName
            "SourceSnapshot" = $snapshotName
            "CreatedBy" = "PowerShell-Script"
            "CreatedDate" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    
    $newDisk = New-AzDisk `
        -ResourceGroupName $sourceRGName `
        -DiskName $newDiskName `
        -Disk $newDiskConfig
    
    Write-Log "New disk created successfully: $($newDisk.Name)" -Level "SUCCESS"
    
    # Step 7: Get existing VNet and subnet information
    Show-ProgressBar -Step 6 -TotalSteps 9 -Activity "Analyzing Network Configuration"
    Write-Log "Step 6: Getting network configuration from source VM..." -Level "STEP"
    
    $sourceNIC = Get-AzNetworkInterface -ResourceId $sourceVM.NetworkProfile.NetworkInterfaces[0].Id
    $subnetId = $sourceNIC.IpConfigurations[0].Subnet.Id
    
    # Parse subnet ID to extract VNet and subnet names
    # Format: /subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/virtualNetworks/{vnetName}/subnets/{subnetName}
    $subnetIdParts = $subnetId -split '/'
    $vnetName = $subnetIdParts[8]  # VNet name is at index 8
    $subnetName = $subnetIdParts[10]  # Subnet name is at index 10
    $vnetResourceGroup = $subnetIdParts[4]  # Resource group is at index 4
    
    Write-Log "🌐 Detected network configuration:" -Level "HEADER"
    Write-Host "┌─────────────────────┬────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "│ Network Component   │ Value                      │" -ForegroundColor DarkGray
    Write-Host "├─────────────────────┼────────────────────────────┤" -ForegroundColor DarkGray
    Write-Host "│ VNet Resource Group │ " -ForegroundColor DarkGray -NoNewline
    Write-Host "$vnetResourceGroup".PadRight(26) -ForegroundColor Cyan -NoNewline
    Write-Host " │" -ForegroundColor DarkGray
    Write-Host "│ VNet Name           │ " -ForegroundColor DarkGray -NoNewline
    Write-Host "$vnetName".PadRight(26) -ForegroundColor Green -NoNewline
    Write-Host " │" -ForegroundColor DarkGray
    Write-Host "│ Subnet Name         │ " -ForegroundColor DarkGray -NoNewline
    Write-Host "$subnetName".PadRight(26) -ForegroundColor Yellow -NoNewline
    Write-Host " │" -ForegroundColor DarkGray
    Write-Host "└─────────────────────┴────────────────────────────┘" -ForegroundColor DarkGray
    
    # Check if VNet is in a different resource group
    if ($vnetResourceGroup -ne $sourceRGName) {
        Write-Log "⚠️  VNet is in a different resource group than the source VM" -Level "WARN"
        Write-Log "  Source VM RG: $sourceRGName" -Level "DETAIL"
        Write-Log "  VNet RG: $vnetResourceGroup" -Level "DETAIL"
        
        # Verify access to the VNet resource group
        $vnetRG = Get-AzResourceGroup -Name $vnetResourceGroup -ErrorAction SilentlyContinue
        if (-not $vnetRG) {
            Write-Log "Cannot access VNet resource group '$vnetResourceGroup'. Check permissions." -Level "ERROR"
            exit 1
        }
    }
    
    # Get VNet and subnet objects
    try {
        $vnet = Get-AzVirtualNetwork -ResourceGroupName $vnetResourceGroup -Name $vnetName -ErrorAction Stop
        $subnet = $vnet.Subnets | Where-Object { $_.Name -eq $subnetName }
        
        if (-not $subnet) {
            Write-Log "Subnet '$subnetName' not found in VNet '$vnetName'" -Level "ERROR"
            exit 1
        }
        
        Write-Log "✅ Successfully accessed network configuration:" -Level "SUCCESS"
        Write-Log "  VNet: $($vnet.Name) (RG: $vnetResourceGroup)" -Level "DETAIL"
        Write-Log "  Subnet: $($subnet.Name)" -Level "DETAIL"
    }
    catch {
        Write-Log "Failed to access VNet '$vnetName' in resource group '$vnetResourceGroup'" -Level "ERROR"
        Write-Log "Error: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Please ensure you have Network Contributor permissions on the VNet resource group" -Level "ERROR"
        exit 1
    }
    
    # Step 8: Create network components for new VM
    Show-ProgressBar -Step 7 -TotalSteps 9 -Activity "Setting Up Network Components"
    Write-Log "Step 7: Creating network components..." -Level "STEP"
    
    # Get source VM's NSG information
    $sourceNSG = $null
    if ($sourceNIC.NetworkSecurityGroup) {
        $sourceNSGId = $sourceNIC.NetworkSecurityGroup.Id
        # Parse NSG details from resource ID
        $nsgResourceParts = $sourceNSGId.Split('/')
        $nsgResourceGroupName = $nsgResourceParts[4]
        $nsgName = $nsgResourceParts[-1]
        
        Write-Output "Getting source NSG: $nsgName from resource group: $nsgResourceGroupName"
        $sourceNSG = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $nsgResourceGroupName
        Write-Log "🛡️  Source VM uses NSG: $($sourceNSG.Name)" -Level "SUCCESS"
        
        # Show NSG rules summary
        $inboundRules = $sourceNSG.SecurityRules | Where-Object {$_.Direction -eq "Inbound" -and $_.Access -eq "Allow"}
        Write-Log "Source NSG has $($inboundRules.Count) inbound allow rule(s)" -Level "DETAIL"
        foreach ($rule in $inboundRules | Select-Object -First 3) {
            Write-Log "  🔓 $($rule.Name): $($rule.Protocol):$($rule.DestinationPortRange) from $($rule.SourceAddressPrefix)" -Level "DETAIL"
        }
    } else {
        Write-Log "⚠️  Source VM has no NSG attached" -Level "WARN"
    }
    
    # Ask user preference for NSG handling
    Write-Host ""
    Write-Log "🛡️  NSG Security Options:" -Level "HEADER"
    Write-Host "┌────┬─────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "│ #  │ NSG Option                                          │" -ForegroundColor DarkGray
    Write-Host "├────┼─────────────────────────────────────────────────────┤" -ForegroundColor DarkGray
    Write-Host "│ 1  │ " -ForegroundColor DarkGray -NoNewline
    Write-Host "🔄 Reuse source VM's NSG (shares security rules)".PadRight(51) -ForegroundColor White -NoNewline
    Write-Host " │" -ForegroundColor DarkGray
    Write-Host "│ 2  │ " -ForegroundColor DarkGray -NoNewline
    Write-Host "🔒 Create new NSG with hardened rules (recommended)".PadRight(51) -ForegroundColor Green -NoNewline
    Write-Host " │" -ForegroundColor DarkGray
    Write-Host "│ 3  │ " -ForegroundColor DarkGray -NoNewline
    Write-Host "📋 Create new NSG copying source rules".PadRight(51) -ForegroundColor Yellow -NoNewline
    Write-Host " │" -ForegroundColor DarkGray
    Write-Host "└────┴─────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
    
    $nsgChoice = Get-UserInput -Prompt "Choose NSG option (1-3)" -DefaultValue "2" -Required $true
    
    $nsg = $null
    switch ($nsgChoice) {
        "1" {
            if ($sourceNSG) {
                $nsg = $sourceNSG
                Write-Log "✅ Will reuse source NSG: $($sourceNSG.Name)" -Level "SUCCESS"
            } else {
                Write-Log "Cannot reuse NSG - source VM has none. Creating new NSG..." -Level "WARN"
                $nsgChoice = "2"  # Fallback to create new
            }
        }
        "3" {
            if ($sourceNSG) {
                # Create new NSG copying source rules
                $nsgName = "$newVMName-nsg"
                Write-Log "📋 Creating new NSG copying source rules..." -Level "STEP"
                
                $copiedRules = @()
                foreach ($rule in $sourceNSG.SecurityRules) {
                    $newRule = New-AzNetworkSecurityRuleConfig `
                        -Name $rule.Name `
                        -Description $rule.Description `
                        -Access $rule.Access `
                        -Protocol $rule.Protocol `
                        -Direction $rule.Direction `
                        -Priority $rule.Priority `
                        -SourceAddressPrefix $rule.SourceAddressPrefix `
                        -SourcePortRange $rule.SourcePortRange `
                        -DestinationAddressPrefix $rule.DestinationAddressPrefix `
                        -DestinationPortRange $rule.DestinationPortRange
                    $copiedRules += $newRule
                }
                
                $nsg = New-AzNetworkSecurityGroup `
                    -ResourceGroupName $sourceRGName `
                    -Location $sourceVM.Location `
                    -Name $nsgName `
                    -SecurityRules $copiedRules `
                    -Tag @{
                        "Purpose" = "VM-$newVMName"
                        "SourceNSG" = $sourceNSG.Name
                        "CreatedBy" = "PowerShell-Script"
                        "CreatedDate" = (Get-Date).ToString("yyyy-MM-dd")
                    }
                
                Write-Log "✅ Created new NSG with copied rules: $nsgName" -Level "SUCCESS"
            } else {
                Write-Log "Cannot copy NSG rules - source VM has none. Creating hardened NSG..." -Level "WARN"
                $nsgChoice = "2"  # Fallback to create new
            }
        }
    }
    
    # Create new hardened NSG if option 2 or fallback
    if ($nsgChoice -eq "2" -or $null -eq $nsg) {
        $nsgName = "$newVMName-nsg"
        $existingNSG = Get-AzNetworkSecurityGroup -ResourceGroupName $sourceRGName -Name $nsgName -ErrorAction SilentlyContinue
        
        if (-not $existingNSG) {
            Write-Log "🔒 Creating hardened NSG with security best practices..." -Level "STEP"
            # Create basic NSG rules based on OS type with security best practices
            $securityRules = @()
            
                if ($sourceVM.StorageProfile.OsDisk.OsType -eq "Windows") {
                # RDP rule with restricted source (VirtualNetwork only for security)
                $rdpRule = New-AzNetworkSecurityRuleConfig `
                    -Name "Allow-RDP-VNet" `
                    -Description "Allow RDP from VirtualNetwork only" `
                    -Access "Allow" `
                    -Protocol "Tcp" `
                    -Direction "Inbound" `
                    -Priority 1000 `
                    -SourceAddressPrefix "VirtualNetwork" `
                    -SourcePortRange "*" `
                    -DestinationAddressPrefix "*" `
                    -DestinationPortRange "3389"
                $securityRules += $rdpRule
            } else {
                # SSH rule with restricted source (VirtualNetwork only for security)
                $sshRule = New-AzNetworkSecurityRuleConfig `
                    -Name "Allow-SSH-VNet" `
                    -Description "Allow SSH from VirtualNetwork only" `
                    -Access "Allow" `
                    -Protocol "Tcp" `
                    -Direction "Inbound" `
                    -Priority 1000 `
                    -SourceAddressPrefix "VirtualNetwork" `
                    -SourcePortRange "*" `
                    -DestinationAddressPrefix "*" `
                    -DestinationPortRange "22"
                $securityRules += $sshRule
            }
            
            # Add explicit deny rule for internet access to management ports (defense in depth)
            $denyInternetRule = New-AzNetworkSecurityRuleConfig `
                -Name "Deny-Internet-Management" `
                -Description "Deny internet access to common management ports" `
                -Access "Deny" `
                -Protocol "*" `
                -Direction "Inbound" `
                -Priority 4000 `
                -SourceAddressPrefix "Internet" `
                -SourcePortRange "*" `
                -DestinationAddressPrefix "*" `
                -DestinationPortRange @("22", "3389", "5985", "5986")
            $securityRules += $denyInternetRule
            
            $nsg = New-AzNetworkSecurityGroup `
                -ResourceGroupName $sourceRGName `
                -Location $sourceVM.Location `
                -Name $nsgName `
                -SecurityRules $securityRules `
                -Tag @{
                    "Purpose" = "VM-$newVMName"
                    "CreatedBy" = "PowerShell-Script"
                    "CreatedDate" = (Get-Date).ToString("yyyy-MM-dd")
                }
        
            Write-Log "✅ Created new NSG with security best practices: $nsgName" -Level "SUCCESS"
        } else {
            $nsg = $existingNSG
            Write-Log "🔄 Using existing NSG: $nsgName" -Level "SUCCESS"
        }
    }
    
    # Create Network Interface with appropriate NSG
    $nicName = "$newVMName-nic"
    
    Write-Log "🌐 Creating network interface in resource group: $sourceRGName" -Level "STEP"
    Write-Log "Connecting to subnet: $subnetName (VNet: $vnetName in RG: $vnetResourceGroup)" -Level "DETAIL"
    
    if ($nsgChoice -eq "1" -and $sourceNSG) {
        # When reusing source NSG, check how it was attached
        if ($sourceNIC.NetworkSecurityGroup) {
            # NSG was attached to source NIC, so attach to new NIC
            $nic = New-AzNetworkInterface `
                -Name $nicName `
                -ResourceGroupName $sourceRGName `
                -Location $sourceVM.Location `
                -SubnetId $subnetId `
                -NetworkSecurityGroupId $nsg.Id
            Write-Log "✅ Created network interface with reused NSG: $nicName" -Level "SUCCESS"
        } else {
            # NSG might be attached at subnet level, create NIC without NSG
            $nic = New-AzNetworkInterface `
                -Name $nicName `
                -ResourceGroupName $sourceRGName `
                -Location $sourceVM.Location `
                -SubnetId $subnetId
            Write-Log "✅ Created network interface (NSG inherited from subnet): $nicName" -Level "SUCCESS"
        }
    } else {
        # Using new or copied NSG, attach to NIC
        $nic = New-AzNetworkInterface `
            -Name $nicName `
            -ResourceGroupName $sourceRGName `
            -Location $sourceVM.Location `
            -SubnetId $subnetId `
            -NetworkSecurityGroupId $nsg.Id
        Write-Log "✅ Created network interface with NSG: $nicName" -Level "SUCCESS"
    }
    
    # Step 9: Configure Boot Diagnostics Storage
    Show-ProgressBar -Step 8 -TotalSteps 10 -Activity "Configuring Boot Diagnostics Storage"
    Write-Log "Step 8: Configuring boot diagnostics storage..." -Level "STEP"
    
    # Check for existing storage account for boot diagnostics
    $diagStorageName = "bootdiag" + (Get-Random -Minimum 1000 -Maximum 9999)
    $existingStorage = Get-AzStorageAccount -ResourceGroupName $sourceRGName -ErrorAction SilentlyContinue | 
        Where-Object { $_.StorageAccountName -like "*bootdiag*" -or $_.StorageAccountName -like "*diag*" } | 
        Select-Object -First 1
    
    if ($existingStorage) {
        Write-Log "📦 Found existing diagnostics storage account: $($existingStorage.StorageAccountName)" -Level "SUCCESS"
        $diagStorageAccount = $existingStorage
        $reuseStorage = Get-UserInput -Prompt "🔄 Reuse existing storage account '$($existingStorage.StorageAccountName)' for boot diagnostics? (Y/n)" -DefaultValue "Y" -Required $false
        
        if ($reuseStorage.ToLower() -eq "n" -or $reuseStorage.ToLower() -eq "no") {
            Write-Log "Creating new storage account for boot diagnostics..." -Level "DETAIL"
            $diagStorageAccount = New-AzStorageAccount `
                -ResourceGroupName $sourceRGName `
                -Name $diagStorageName `
                -Location $sourceVM.Location `
                -SkuName "Standard_LRS" `
                -Kind "StorageV2" `
                -Tag @{
                    "Purpose" = "Boot Diagnostics"
                    "CreatedFor" = $newVMName
                    "CreatedBy" = "PowerShell Script"
                }
            Write-Log "✅ Created new storage account: $diagStorageName" -Level "SUCCESS"
        }
    } else {
        Write-Log "No existing boot diagnostics storage found. Creating new storage account..." -Level "DETAIL"
        $diagStorageAccount = New-AzStorageAccount `
            -ResourceGroupName $sourceRGName `
            -Name $diagStorageName `
            -Location $sourceVM.Location `
            -SkuName "Standard_LRS" `
            -Kind "StorageV2" `
            -Tag @{
                "Purpose" = "Boot Diagnostics"
                "CreatedFor" = $newVMName
                "CreatedBy" = "PowerShell Script"
            }
        Write-Log "✅ Created new storage account: $diagStorageName" -Level "SUCCESS"
    }
    
    # Step 10: Create VM configuration
    Show-ProgressBar -Step 9 -TotalSteps 10 -Activity "Building VM Configuration"
    Write-Log "Step 9: Creating VM configuration..." -Level "STEP"
    
    $vmConfig = New-AzVMConfig -VMName $newVMName -VMSize $newVMSize
    
    # Add network interface
    $vm = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
    
    # Attach the new disk as OS disk
    if ($sourceVM.StorageProfile.OsDisk.OsType -eq "Windows") {
        $vm = Set-AzVMOSDisk -VM $vm -ManagedDiskId $newDisk.Id -CreateOption "Attach" -Windows
    } else {
        $vm = Set-AzVMOSDisk -VM $vm -ManagedDiskId $newDisk.Id -CreateOption "Attach" -Linux
    }
    
    # Configure boot diagnostics with the selected storage account
    $vm = Set-AzVMBootDiagnostic -VM $vm -Enable -ResourceGroupName $sourceRGName -StorageAccountName $diagStorageAccount.StorageAccountName
    Write-Log "🔧 Configured boot diagnostics with storage account: $($diagStorageAccount.StorageAccountName)" -Level "DETAIL"
    
    # Step 11: Create the VM
    Show-ProgressBar -Step 10 -TotalSteps 10 -Activity "Deploying Virtual Machine"
    Write-Log "Step 10: Creating virtual machine '$newVMName'..." -Level "STEP"
    Write-Log "🚀 This may take several minutes..." -Level "DETAIL"
    
    $vmResult = New-AzVM `
        -ResourceGroupName $sourceRGName `
        -Location $sourceVM.Location `
        -VM $vm `
        -Tag @{
            "Source" = "Snapshot from $sourceVMName"
            "SnapshotName" = $snapshotName
            "CreatedBy" = "PowerShell Script"
            "CreatedDate" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    
    if ($vmResult.IsSuccessStatusCode) {
        Write-Host ""
        Write-Host "🎉🎉🎉 SUCCESS! 🎉🎉🎉" -ForegroundColor Green
        Write-Log "Virtual machine '$newVMName' created successfully!" -Level "SUCCESS"
        
        # Display Microsoft-style success banner
        Write-Host ""
        Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
        Write-Host "║                                                                        ║" -ForegroundColor Blue
        Write-Host "║   ███╗   ███╗██╗ ██████╗██████╗  ██████╗ ███████╗ ██████╗ ███████╗     ║" -ForegroundColor Blue
        Write-Host "║   ████╗ ████║██║██╔════╝██╔══██╗██╔═══██╗██╔════╝██╔═══██╗██╔════╝     ║" -ForegroundColor Blue
        Write-Host "║   ██╔████╔██║██║██║     ██████╔╝██║   ██║███████╗██║   ██║█████╗       ║" -ForegroundColor Blue
        Write-Host "║   ██║╚██╔╝██║██║██║     ██╔══██╗██║   ██║╚════██║██║   ██║██╔══╝       ║" -ForegroundColor Blue
        Write-Host "║   ██║ ╚═╝ ██║██║╚██████╗██║  ██║╚██████╔╝███████║╚██████╔╝██║          ║" -ForegroundColor Blue
        Write-Host "║   ╚═╝     ╚═╝╚═╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝          ║" -ForegroundColor Blue
        Write-Host "║                                                                        ║" -ForegroundColor Blue
        Write-Host "║                         🎯 VM CREATION SUMMARY                        ║" -ForegroundColor Blue
        Write-Host "║                      VM Cloned Successfully!                           ║" -ForegroundColor Blue
        Write-Host "║                                                                        ║" -ForegroundColor Blue
        Write-Host "╠════════════════════════════════════════════════════════════════════════╣" -ForegroundColor Blue
        Write-Host "║ Source VM    │ " -ForegroundColor Blue -NoNewline
        Write-Host "$sourceVMName".PadRight(51) -ForegroundColor White -NoNewline
        Write-Host " ║" -ForegroundColor Blue
        Write-Host "║ New VM       │ " -ForegroundColor Blue -NoNewline
        Write-Host "$newVMName".PadRight(51) -ForegroundColor Cyan -NoNewline
        Write-Host " ║" -ForegroundColor Blue
        Write-Host "║ Resource Grp │ " -ForegroundColor Blue -NoNewline
        Write-Host "$sourceRGName".PadRight(51) -ForegroundColor Yellow -NoNewline
        Write-Host " ║" -ForegroundColor Blue
        Write-Host "║ Location     │ " -ForegroundColor Blue -NoNewline
        Write-Host "$($sourceVM.Location)".PadRight(51) -ForegroundColor Magenta -NoNewline
        Write-Host " ║" -ForegroundColor Blue
        Write-Host "║ VM Size      │ " -ForegroundColor Blue -NoNewline
        Write-Host "$newVMSize".PadRight(51) -ForegroundColor Green -NoNewline
        Write-Host " ║" -ForegroundColor Blue
        Write-Host "║ OS Type      │ " -ForegroundColor Blue -NoNewline
        Write-Host "$($sourceVM.StorageProfile.OsDisk.OsType)".PadRight(51) -ForegroundColor DarkGreen -NoNewline
        Write-Host " ║" -ForegroundColor Blue
        Write-Host "║ VNet         │ " -ForegroundColor Blue -NoNewline
        Write-Host "$($vnet.Name)".PadRight(51) -ForegroundColor DarkCyan -NoNewline
        Write-Host " ║" -ForegroundColor Blue
        Write-Host "║ Subnet       │ " -ForegroundColor Blue -NoNewline
        Write-Host "$($subnet.Name)".PadRight(51) -ForegroundColor DarkYellow -NoNewline
        Write-Host " ║" -ForegroundColor Blue
        Write-Host "║ Private IP   │ " -ForegroundColor Blue -NoNewline
        Write-Host "$($nic.IpConfigurations[0].PrivateIpAddress)".PadRight(51) -ForegroundColor DarkGreen -NoNewline
        Write-Host " ║" -ForegroundColor Blue
        Write-Host "║ Boot Diag    │ " -ForegroundColor Blue -NoNewline
        Write-Host "$($diagStorageAccount.StorageAccountName)".PadRight(51) -ForegroundColor DarkMagenta -NoNewline
        Write-Host " ║" -ForegroundColor Blue
        Write-Host "╚════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
        
        Write-Host ""
        Write-Log "🎯 Next Steps:" -Level "HEADER"
        Write-Log "✅ VM is ready for use with the same configuration as source VM" -Level "SUCCESS"
        Write-Log "🖥️  Computer name and settings are preserved from original VM" -Level "DETAIL"
        Write-Log "🔒 Original VM and disk remain unchanged" -Level "DETAIL"
        Write-Log "💾 Snapshot is retained for future use if needed" -Level "DETAIL"
        Write-Log "🔑 Connect via RDP/SSH using the same credentials as source VM" -Level "DETAIL"
        
        # Resource cleanup option
        Write-Host ""
        $cleanupSnapshot = Get-UserInput -Prompt "💰 Do you want to delete the snapshot to save costs? (y/N)" -DefaultValue "N" -Required $false
        if ($cleanupSnapshot.ToLower() -eq "y" -or $cleanupSnapshot.ToLower() -eq "yes") {
            Write-Log "🗑️  Deleting snapshot..." -Level "STEP"
            Remove-AzSnapshot -ResourceGroupName $sourceRGName -SnapshotName $snapshotName -Force
            Write-Log "✅ Snapshot deleted successfully" -Level "SUCCESS"
        } else {
            Write-Log "💾 Snapshot retained. You can delete it later if not needed:" -Level "DETAIL"
            Write-Log "Remove-AzSnapshot -ResourceGroupName '$sourceRGName' -SnapshotName '$snapshotName' -Force" -Level "DETAIL"
        }
        
    } else {
        Write-Log "Failed to create virtual machine. Check the error details above." -Level "ERROR"
        exit 1
    }
    
} # End of main try block
catch {
    Write-Log "💥 An error occurred: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Full error details: $($_.Exception.ToString())" -Level "ERROR"
    
    # Cleanup on error
    Write-Log "🧹 Attempting cleanup of created resources..." -Level "WARN"
    
    try {
        # Remove VM if it was partially created
        $createdVM = Get-AzVM -ResourceGroupName $sourceRGName -Name $newVMName -ErrorAction SilentlyContinue
        if ($createdVM) {
            Write-Log "🗑️  Removing partially created VM..." -Level "WARN"
            Remove-AzVM -ResourceGroupName $sourceRGName -Name $newVMName -Force
        }
        
        # Remove network interface if created
        if ($nic) {
            Remove-AzNetworkInterface -ResourceGroupName $sourceRGName -Name $nicName -Force -ErrorAction SilentlyContinue
        }
        
        # Remove disk if created
        if ($newDisk) {
            Remove-AzDisk -ResourceGroupName $sourceRGName -DiskName $newDiskName -Force -ErrorAction SilentlyContinue
        }
        
        # Remove snapshot if created
        if ($snapshot) {
            Remove-AzSnapshot -ResourceGroupName $sourceRGName -SnapshotName $snapshotName -Force -ErrorAction SilentlyContinue
        }
        
        # Remove storage account if created and not reused
        if ($diagStorageAccount -and $diagStorageAccount.StorageAccountName -like "*bootdiag*" -and -not $existingStorage) {
            Remove-AzStorageAccount -ResourceGroupName $sourceRGName -Name $diagStorageAccount.StorageAccountName -Force -ErrorAction SilentlyContinue
        }
        
        Write-Log "✅ Cleanup completed" -Level "SUCCESS"
    }
    catch {
        Write-Log "⚠️  Error during cleanup: $($_.Exception.Message)" -Level "WARN"
    }
    
    exit 1
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Host "███╗   ███╗██╗ ██████╗██████╗  ██████╗ ███████╗ ██████╗ ███████╗████████╗" -ForegroundColor Blue
Write-Host "████╗ ████║██║██╔════╝██╔══██╗██╔═══██╗██╔════╝██╔═══██╗██╔════╝╚══██╔══╝" -ForegroundColor Blue
Write-Host "██╔████╔██║██║██║     ██████╔╝██║   ██║███████╗██║   ██║█████╗     ██║   " -ForegroundColor Blue
Write-Host "██║╚██╔╝██║██║██║     ██╔══██╗██║   ██║╚════██║██║   ██║██╔══╝     ██║   " -ForegroundColor Blue
Write-Host "██║ ╚═╝ ██║██║╚██████╗██║  ██║╚██████╔╝███████║╚██████╔╝██║        ██║   " -ForegroundColor Blue
Write-Host "╚═╝     ╚═╝╚═╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝        ╚═╝   " -ForegroundColor Blue
Write-Host ""
Write-Host "            🚀 AZURE VM CLONING COMPLETED! 🚀" -ForegroundColor White -BackgroundColor Blue
Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor Blue
Write-Log "Script completed successfully!" -Level "SUCCESS"

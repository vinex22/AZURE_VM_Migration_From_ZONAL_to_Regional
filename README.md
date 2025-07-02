# Azure VM Cloning Automation

🚀 **Enterprise-grade PowerShell script for automated Azure Virtual Machine cloning using disk snapshots**

![Microsoft Azure](https://img.shields.io/badge/Microsoft%20Azure-0078D4?style=for-the-badge&logo=microsoft-azure&logoColor=white)
![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)

## 🎯 Overview

This PowerShell automation script provides a fast, reliable, and secure way to clone Azure Virtual Machines by creating snapshots of the source VM's OS disk and deploying new VMs from those snapshots. Perfect for development, testing, disaster recovery, and rapid environment provisioning.

### ✨ Key Features

- 🔄 **Non-disruptive Cloning**: Source VM remains running during the cloning process
- 🌐 **Cross-Resource Group Support**: Handle VNets in different resource groups
- 🛡️ **Advanced Security**: Multiple NSG options with hardened security rules
- 💾 **Intelligent Storage Management**: Smart boot diagnostics storage account reuse
- 🎨 **Professional UI**: Microsoft-branded interface with colorful progress indicators
- 🧹 **Robust Error Handling**: Comprehensive cleanup and error recovery
- 📊 **Detailed Reporting**: Enterprise-grade summary and logging

## 🚀 Quick Start

### Prerequisites

- Azure PowerShell modules: `Az.Accounts`, `Az.Compute`, `Az.Resources`, `Az.Network`
- Azure subscription with Contributor permissions
- PowerShell 5.1 or PowerShell 7+

### Installation

1. **Clone this repository**
   ```powershell
   git clone https://github.com/YOUR_USERNAME/azure-vm-cloning.git
   cd azure-vm-cloning
   ```

2. **Run the environment test** (recommended)
   ```powershell
   .\test-azure-environment.ps1
   ```

3. **Execute the cloning script**
   ```powershell
   .\create-vm-from-snapshot.ps1
   ```

## 📋 What the Script Does

### Step-by-Step Process

1. **🔐 Azure Authentication**: Validates your Azure connection and permissions
2. **📝 Source VM Selection**: Interactive selection from available VMs and resource groups  
3. **💿 OS Disk Analysis**: Analyzes the source VM's OS disk configuration
4. **⚙️ New VM Configuration**: Configure VM size, naming, and options
5. **📸 Snapshot Creation**: Creates a snapshot of the source OS disk (non-disruptive)
6. **💾 Disk Creation**: Creates a new managed disk from the snapshot
7. **🌐 Network Configuration**: Handles VNet, subnet, and NSG configuration
8. **🗄️ Storage Management**: Intelligent boot diagnostics storage account handling
9. **🖥️ VM Deployment**: Deploys the new VM with the cloned disk
10. **📊 Success Reporting**: Comprehensive summary with Microsoft branding

## 🛡️ Security Features

### Network Security Groups (NSG) Options

Choose from three security approaches:

1. **🔄 Reuse Source NSG**: Share security rules with the source VM
2. **🔒 Create Hardened NSG**: New NSG with security best practices (recommended)
3. **📋 Copy Source Rules**: Create new NSG copying existing rules

### Security Best Practices

- ✅ Restricts RDP/SSH access to VirtualNetwork only
- ✅ Explicit deny rules for internet access to management ports
- ✅ Proper resource tagging for security compliance
- ✅ Managed disk encryption support
- ✅ Least privilege access patterns

## 💰 Cost Optimization

### Storage Account Management

The script intelligently manages boot diagnostics storage accounts:

- **🔍 Discovery**: Automatically finds existing boot diagnostics storage
- **💡 User Choice**: Interactive prompts for storage reuse decisions
- **💰 Cost Savings**: Prevents unnecessary storage account proliferation
- **🏷️ Proper Tagging**: Resources tagged for cost tracking and management

### Estimated Costs

- **Snapshot Storage**: ~$0.05/GB/month (Standard_LRS)
- **New VM**: Based on selected VM size and disk type
- **Boot Diagnostics**: ~$2-5/month per storage account (when not reused)

## 📖 Usage Examples

### Basic Cloning
```powershell
# Run with default settings
.\create-vm-from-snapshot.ps1
```

### Environment Testing
```powershell
# Validate your Azure environment first
.\test-azure-environment.ps1
```

## 🔧 Configuration Options

### Supported VM Sizes
- **Burstable**: B-series (Standard_B2s, Standard_B2ms)
- **General Purpose**: D-series (Standard_D2s_v3, Standard_D4s_v3)
- **Custom**: Any Azure VM size available in your region

### Disk Types
- **Standard_LRS**: Cost-effective standard storage
- **Premium_LRS**: High-performance SSD storage (automatic upgrade option)

### Network Configurations
- **Same Resource Group**: Standard deployment
- **Cross-Resource Group**: VNet in different resource group
- **Custom Subnets**: Flexible subnet selection



## 🏆 Enterprise Features

### Microsoft Branding
- Professional Microsoft Azure branded interface
- Corporate-standard visual design
- Enterprise-grade user experience

### Logging and Monitoring
- Comprehensive logging with timestamps
- Color-coded status indicators
- Detailed progress reporting
- Error tracking and recovery

### Resource Management
- Proper resource tagging
- Cleanup on failures
- Resource group organization
- Cost tracking support

## 🐛 Troubleshooting

### Common Issues

1. **Authentication Errors**
   ```powershell
   Connect-AzAccount
   Select-AzSubscription -SubscriptionId "your-subscription-id"
   ```

2. **Permission Issues**
   - Ensure you have Contributor role on the subscription
   - Verify access to VNet resource groups

3. **Module Installation**
   ```powershell
   Install-Module -Name Az.Accounts, Az.Compute, Az.Resources, Az.Network -Force
   ```

### Getting Help

- **Environment Issues**: Run `.\test-azure-environment.ps1` for diagnostics
- **Script Errors**: Check the detailed error logs in the output
- **Permissions**: Contact your Azure administrator

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

### Development Guidelines
- Follow PowerShell best practices
- Maintain Microsoft branding consistency
- Include comprehensive error handling
- Add appropriate documentation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Related Resources

- [Azure PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/azure/)
- [Azure VM Documentation](https://docs.microsoft.com/en-us/azure/virtual-machines/)
- [Azure Disk Snapshots](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/snapshot-copy-managed-disk)
- [Azure Network Security Groups](https://docs.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview)

## 📧 Contact

**Author**: vinayjain@microsoft.com  
**Version**: 2.4 - Microsoft Branded

---

⭐ **If this script helps you, please give it a star!** ⭐

Made with ❤️ for the Azure community

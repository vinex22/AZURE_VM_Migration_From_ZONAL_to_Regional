# Contributing to Azure VM Cloning

Thank you for your interest in contributing to the Azure VM Cloning project! This document provides guidelines and information for contributors.

## 🤝 How to Contribute

### Reporting Bugs

1. **Check existing issues** to avoid duplicates
2. **Use the bug report template** when creating new issues
3. **Provide detailed information**:
   - PowerShell version
   - Azure PowerShell module versions
   - Error messages and logs
   - Steps to reproduce
   - Expected vs. actual behavior

### Suggesting Enhancements

1. **Check existing feature requests** to avoid duplicates
2. **Provide clear use cases** and justification
3. **Include implementation suggestions** if possible
4. **Consider backward compatibility** implications

### Code Contributions

#### Prerequisites
- PowerShell 5.1 or PowerShell 7+
- Azure PowerShell modules
- Git knowledge
- Understanding of Azure concepts

#### Development Process

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes** following our coding standards
4. **Test thoroughly** using the test script
5. **Update documentation** as needed
6. **Commit with clear messages**
7. **Submit a pull request**

## 📝 Coding Standards

### PowerShell Best Practices

#### Function Design
```powershell
function Verb-Noun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RequiredParameter,
        
        [string]$OptionalParameter = "default"
    )
    
    # Implementation
}
```

#### Error Handling
```powershell
try {
    # Operation that might fail
    $result = Get-AzResource -ErrorAction Stop
}
catch {
    Write-Log "Error: $($_.Exception.Message)" -Level "ERROR"
    throw
}
```

#### Logging Standards
```powershell
# Use consistent logging with our Write-Log function
Write-Log "Operation started" -Level "STEP"
Write-Log "Detailed information" -Level "DETAIL"
Write-Log "Success message" -Level "SUCCESS"
Write-Log "Warning message" -Level "WARN"
Write-Log "Error occurred" -Level "ERROR"
```

### Microsoft Branding Guidelines

#### Color Scheme
- **Primary**: Microsoft Blue (`Blue`)
- **Success**: Green
- **Warning**: Yellow
- **Error**: Red
- **Info**: Cyan

#### ASCII Art and Banners
- Maintain Microsoft branding consistency
- Use appropriate padding and alignment
- Follow existing layout patterns

#### Progress Indicators
```powershell
# Use the standard progress format
Write-Host "Microsoft Progress: [$progressBar] $percentage% - $Activity" -ForegroundColor Blue
```

## 🧪 Testing Guidelines

### Manual Testing
1. **Run the environment test**
   ```powershell
   .\test-azure-environment.ps1
   ```

2. **Test the main script**
   ```powershell
   .\create-vm-from-snapshot.ps1
   ```

3. **Test different scenarios**:
   - Different VM sizes
   - Cross-resource group VNets
   - Various NSG configurations
   - Storage account reuse options

### Test Environments
- Test with different Azure subscription types
- Validate across different Azure regions
- Test with various VM configurations
- Verify permission scenarios

## 📚 Documentation Standards

### Code Comments
```powershell
<#
.SYNOPSIS
    Brief description of the function

.DESCRIPTION
    Detailed description of what the function does

.PARAMETER ParameterName
    Description of the parameter

.EXAMPLE
    Example usage of the function

.NOTES
    Additional notes or requirements
#>
```

### README Updates
- Update features list for new functionality
- Add usage examples for new features
- Update troubleshooting section if needed
- Maintain consistent formatting

### Changelog
- Follow [Keep a Changelog](https://keepachangelog.com/) format
- Categorize changes: Added, Changed, Fixed, Removed
- Include version numbers and dates
- Reference issue numbers where applicable

## 🎯 Areas for Contribution

### High Priority
- [ ] Automated testing framework
- [ ] Performance optimizations for large VMs
- [ ] Additional VM size recommendations
- [ ] Enhanced error recovery mechanisms

### Medium Priority
- [ ] Support for additional disk types
- [ ] Advanced network configurations
- [ ] Integration with Azure DevOps
- [ ] PowerShell Gallery packaging

### Documentation
- [ ] Video tutorials
- [ ] Advanced usage scenarios
- [ ] Troubleshooting guides
- [ ] Best practices documentation

## 🐛 Bug Triage Process

### Severity Levels
- **Critical**: Script fails to run or causes data loss
- **High**: Major functionality broken
- **Medium**: Minor functionality issues
- **Low**: Cosmetic or documentation issues

### Resolution Timeline
- **Critical**: 24-48 hours
- **High**: 1 week
- **Medium**: 2-4 weeks
- **Low**: Next release cycle

## 🔍 Code Review Process

### Review Criteria
1. **Functionality**: Does it work as intended?
2. **Code Quality**: Follows PowerShell best practices?
3. **Security**: No security vulnerabilities?
4. **Performance**: Efficient implementation?
5. **Documentation**: Adequately documented?
6. **Testing**: Properly tested?
7. **Branding**: Maintains Microsoft consistency?

### Review Checklist
- [ ] Code follows established patterns
- [ ] Error handling is comprehensive
- [ ] Logging is appropriate and consistent
- [ ] Documentation is updated
- [ ] Breaking changes are noted
- [ ] Security implications considered
- [ ] Performance impact assessed

## 📞 Getting Help

### Communication Channels
- **Issues**: Use GitHub issues for bugs and feature requests
- **Discussions**: Use GitHub discussions for questions
- **Email**: Contact maintainer at vinayjain@microsoft.com

### Response Times
- **Bug reports**: 48 hours
- **Feature requests**: 1 week
- **Questions**: 24-48 hours
- **Pull requests**: 3-5 business days

## 🏆 Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- CHANGELOG.md

### Types of Contributions
- 🐛 **Bug fixes**
- ✨ **New features**
- 📝 **Documentation**
- 🎨 **UI/UX improvements**
- ⚡ **Performance improvements**
- 🔒 **Security enhancements**

## 📋 Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Other (please describe)

## Testing
- [ ] Tested with test-azure-environment.ps1
- [ ] Tested main functionality
- [ ] Tested edge cases
- [ ] Updated documentation

## Screenshots (if applicable)
Add screenshots of UI changes

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
```

## 📄 License

By contributing to this project, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to the Azure VM Cloning project! Your efforts help make Azure automation better for everyone. 🚀

# Windows Server 2022 Packer Build for Proxmox

Automated Windows Server 2022 template creation using HashiCorp Packer and Proxmox VE.

## Overview

This project automates the creation of a Windows Server 2022 VM template on Proxmox using Packer. The template includes:

- Automated Windows installation via unattended.xml
- VirtIO drivers for optimal performance
- IIS (Internet Information Services) pre-installed
- Multi-phase provisioning with PowerShell scripts
- Sysprep generalization for template deployment
- Optional Windows Update integration

## Prerequisites

### Required Software
- [HashiCorp Packer](https://www.packer.io/downloads) (>= 1.8.0)
- Proxmox VE server with API access
- Proxmox API token with appropriate permissions

### Required ISO Files
Ensure these ISOs are uploaded to your Proxmox server in the `local` storage:
- `Win-Server-2022.iso` - Windows Server 2022 installation media
- `virtio-win.iso` - VirtIO drivers for Windows

## Project Structure

```
.
├── windows-server-2022.pkr.hcl    # Main Packer configuration
├── variables.pkrvars.hcl           # Variable definitions (API credentials)
├── build.sh                        # Build script
└── data2/                          # Provisioning files
    ├── Autounattend.xml           # Unattended Windows installation
    ├── bootstrap.ps1              # Initial WinRM setup
    ├── windows-init.ps1           # Windows initialization
    ├── phase-1.ps1                # Phase 1 provisioning
    ├── phase-2.ps1                # Phase 2 provisioning
    ├── phase-3.ps1                # Phase 3 provisioning
    ├── phase-4.windows-updates.ps1 # Windows updates
    ├── phase-5a.software.ps1      # Software installation
    ├── phase-5b.docker.ps1        # Docker installation
    ├── phase-5c.vagrant.ps1       # Vagrant setup
    ├── phase-5d.windows-compress.ps1 # Disk compression
    ├── install-iis.ps1            # IIS installation
    ├── extend-trial.cmd           # Windows trial extension
    └── unattend.xml               # Sysprep answer file
```

## Configuration

### 1. Set Environment Variables

Create or modify `variables.pkrvars.hcl` with your Proxmox credentials:

```hcl
proxmox_api_url                  = "https://your-proxmox-server:8006/api2/json"
proxmox_api_token_id            = "packer@pve!automation1"
proxmox_api_token_secret        = "your-token-secret-here"
proxmox_insecure_skip_tls_verify = true
# vm_vlan_tag = "30"  # Optional: Uncomment to set VLAN
```

**Security Note:** Never commit `variables.pkrvars.hcl` with real credentials to version control. Consider using environment variables instead:

```bash
export PROXMOX_API_URL="https://your-proxmox-server:8006/api2/json"
export PROXMOX_API_TOKEN_ID="packer@pve!automation1"
export PROXMOX_API_TOKEN_SECRET="your-token-secret"
export VM_VLAN_TAG="30"  # Optional
```

### 2. Customize VM Settings

Edit `windows-server-2022.pkr.hcl` to adjust:

- **Node:** Change `node = "pve3"` to your Proxmox node name
- **Storage:** Modify `storage_pool = "local-lvm"` to your storage
- **Resources:** Adjust `memory = "4096"` and `cores = "2"` as needed
- **Network:** Configure `bridge`, `vlan_tag`, etc.
- **Disk Size:** Change `disk_size = "50G"` if needed

### 3. Admin Password

The default administrator password is set in the Packer config:
```hcl
winrm_username = "Administrator"
winrm_password = "password"
```

**⚠️ Change this password** in both:
- `windows-server-2022.pkr.hcl` (winrm_password)
- `data2/Autounattend.xml` (Administrator password)

## Usage

### Initialize Packer Plugins

Before first use, initialize required plugins:

```bash
packer init .
```

### Build the Template

#### Option 1: Using the build script
```bash
chmod +x build.sh
./build.sh
```

#### Option 2: Using Packer directly
```bash
packer build -var-file=variables.pkrvars.hcl windows-server-2022.pkr.hcl
```

### Build Process

The build typically takes 45-90 minutes and includes:

1. **VM Creation** - Creates VM with specified resources
2. **Windows Installation** - Automated via Autounattend.xml
3. **Driver Installation** - VirtIO drivers from mounted ISO
4. **WinRM Setup** - Establishes communication for provisioning
5. **Phase 1 Provisioning** - Base configuration
6. **Restart** - First reboot
7. **Phase 2 Provisioning** - Additional setup
8. **IIS Installation** - Installs web server role
9. **Restart** - Second reboot
10. **Optional Updates** - Windows Update (if enabled)
11. **Disk Compression** - Reduces template size
12. **Sysprep** - Generalizes the image for deployment

## Build Details

### Required Packer Plugins

- **proxmox** (>= 1.2.3) - Proxmox builder
- **windows-update** (0.15.0) - Windows Update provisioner

### Provisioning Phases

The build uses a multi-phase approach with WinRM reconfiguration after each restart:

```hcl
# After each restart, WinRM must be reconfigured:
provisioner "powershell" {
  inline = [
    "winrm set winrm/config/service '@{AllowUnencrypted=\"true\"}'",
    "winrm set winrm/config/client '@{AllowUnencrypted=\"true\"}'" 
  ]
}
```

### Windows Updates

Windows Updates are commented out by default for faster builds:

```hcl
#provisioner "windows-update" {
#  search_criteria = "IsInstalled=0"
#  update_limit = 10
#}
```

Uncomment this section in `windows-server-2022.pkr.hcl` to enable updates.

## Deployment

After successful build, the template `win2022-baseline` will be available in Proxmox:

1. Right-click the template in Proxmox UI
2. Select "Clone"
3. Choose "Full Clone" or "Linked Clone"
4. Deploy your new VM

The VM will boot and automatically run through OOBE (Out-of-Box Experience) with the settings from `unattend.xml`.

## Troubleshooting

### Common Issues

**Build fails during Windows installation:**
- Verify ISO files are present in Proxmox storage
- Check `Autounattend.xml` for correct product key or remove it
- Ensure sufficient resources (RAM/CPU) are allocated

**WinRM timeout:**
- Increase `winrm_timeout` in the source block
- Check firewall rules in Proxmox
- Verify WinRM is enabled in `bootstrap.ps1`

**Sysprep fails:**
- Review `C:\Windows\System32\Sysprep\Panther\setuperr.log` on the VM
- Ensure all provisioning scripts completed successfully
- Check `unattend.xml` syntax

### Debug Mode

Run Packer with debug flag for detailed output:

```bash
PACKER_LOG=1 packer build -var-file=variables.pkrvars.hcl windows-server-2022.pkr.hcl
```

## Security Considerations

- **Change default passwords** before production use
- **Use secure API tokens** with minimal required permissions
- **Enable TLS verification** (`proxmox_insecure_skip_tls_verify = false`) with valid certificates
- **Review provisioning scripts** before execution
- **Keep credentials out of version control** - use environment variables or secrets management

## Customization

### Adding Software

Add your software installation to provisioning scripts:

```powershell
# In data2/phase-5a.software.ps1
choco install googlechrome -y
choco install notepadplusplus -y
```

### Modifying Unattended Installation

Edit `data2/Autounattend.xml` to customize:
- Regional settings
- Disk partitioning
- User accounts
- Windows features

### Adding Provisioners

Add additional provisioners in `windows-server-2022.pkr.hcl`:

```hcl
provisioner "powershell" {
  script = "./data2/your-custom-script.ps1"
}
```

## License

This project is provided as-is for educational and automation purposes.

## Contributing

Feel free to submit issues or pull requests for improvements.

## Resources

- [Packer Documentation](https://www.packer.io/docs)
- [Proxmox Packer Plugin](https://github.com/hashicorp/packer-plugin-proxmox)
- [Windows Answer Files](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/update-windows-settings-and-scripts-create-your-own-answer-file-sxs)
- [VirtIO Drivers](https://pve.proxmox.com/wiki/Windows_VirtIO_Drivers)

---

**Built with ❤️ for automated infrastructure**

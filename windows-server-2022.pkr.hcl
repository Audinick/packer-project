packer {
    required_plugins {
        proxmox = {
            version = ">= 1.2.3"
            source = "github.com/hashicorp/proxmox"
        }
        windows-update = {
            version = "0.15.0"
            source = "github.com/rgl/windows-update"
        }
    }
}

variable "proxmox_api_url" {
    type    = string
    default = env("PROXMOX_API_URL")
}
variable "proxmox_api_token_id" {
    type    = string
    default = env("PROXMOX_API_TOKEN_ID")
}
variable "proxmox_api_token_secret" {
    type      = string
    default   = env("PROXMOX_API_TOKEN_SECRET")
    sensitive = true
}
variable "proxmox_insecure_skip_tls_verify" {
    type    = bool
    # No default: supply this in your .pkrvars.hcl
}
variable "vm_vlan_tag" {
    type    = string
    default = env("VM_VLAN_TAG")
}

source "proxmox-iso" "win-2022" {
    proxmox_url              = var.proxmox_api_url
    username                 = var.proxmox_api_token_id
    token                    = var.proxmox_api_token_secret
    insecure_skip_tls_verify = var.proxmox_insecure_skip_tls_verify

    node              = "pve3"
    vm_name           = "win2022-baseline"
    template_description = "Automated Windows Server 2022 Build"
    machine           = "q35"
    bios              = "ovmf"
    scsi_controller   = "virtio-scsi-single"

    disks {
        disk_size    = "50G"
        storage_pool = "local-lvm"
        type         = "virtio"
        format       = "raw"
    }

    efi_config {
        efi_storage_pool    = "local-lvm"
        efi_type            = "4m"
        pre_enrolled_keys   = true
    }

    boot_command      = ["<space><wait3s><space><wait3s><space><wait3s><space>"]
    boot_wait         = "5s"

    os                = "win10"

    boot_iso {
        iso_file         = "local:iso/Win-Server-2022.iso"
        iso_storage_pool = "local"
        type             = "ide"
        index            = 0
        unmount          = true
    }

    additional_iso_files {
        unmount          = true
        type             = "sata"
        index            = 4
        iso_storage_pool = "local"
        cd_files         = ["data2/Autounattend.xml", "data2/bootstrap.ps1"]
    }

    additional_iso_files {
        unmount          = true
        type             = "sata"
        index            = 5
        iso_storage_pool = "local"
        iso_file         = "local:iso/virtio-win.iso"
    }

    network_adapters {
        bridge      = "vmbr0"
        model       = "virtio"
        vlan_tag    = var.vm_vlan_tag
        firewall    = "false"
        mac_address = "repeatable"
    }

    memory = "4096"
    cores  = "2"

    communicator     = "winrm"
    winrm_username   = "Administrator"
    winrm_password   = "password"
    winrm_timeout    = "1h"

    qemu_agent  = true
}

build {
    sources = ["source.proxmox-iso.win-2022"]

    # --- WINRM: First provisioner ---
    provisioner "powershell" {
        inline = [
            "winrm set winrm/config/service '@{AllowUnencrypted=\"true\"}'",
            "winrm set winrm/config/client '@{AllowUnencrypted=\"true\"}'"
        ]
    }

    provisioner "powershell" {
        script = "./data2/phase-1.ps1"
    }

    provisioner "windows-restart" {
        restart_timeout = "1h"
    }

    # --- WINRM: After first restart ---
    provisioner "powershell" {
        inline = [
            "winrm set winrm/config/service '@{AllowUnencrypted=\"true\"}'",
            "winrm set winrm/config/client '@{AllowUnencrypted=\"true\"}'"
        ]
    }

    # Configure DNS servers
    provisioner "powershell" {
        inline = [
            "Write-Host 'Configuring DNS servers...'",
            "Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object {",
            "    Write-Host \"Setting DNS for adapter: $($_.Name)\"",
            "    Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses ('8.8.8.8','8.8.4.4','1.1.1.1')",
            "}",
            "",
            "Write-Host 'Verifying DNS configuration...'",
            "Get-DnsClientServerAddress -AddressFamily IPv4",
            "",
            "Write-Host 'Testing DNS resolution...'",
            "nslookup google.com 8.8.8.8",
            "",
            "Write-Host 'Flushing DNS cache...'",
            "ipconfig /flushdns",
            "",
            "Write-Host 'DNS configuration complete'",
            "Start-Sleep -Seconds 10"
        ]
    }


    provisioner "powershell" {
        script = "./data2/phase-2.ps1"
    }

    provisioner "powershell" {
        script = "./data2/install-iis.ps1"
    }

    provisioner "windows-restart" {
        restart_timeout = "1h"
    }

    # --- WINRM: After second restart ---
    provisioner "powershell" {
        inline = [
            "winrm set winrm/config/service '@{AllowUnencrypted=\"true\"}'",
            "winrm set winrm/config/client '@{AllowUnencrypted=\"true\"}'"
        ]
    }

    # Test network connectivity before updates
    provisioner "powershell" {
        inline = [
            "Write-Host '========================================='",
            "Write-Host 'Testing network connectivity...'",
            "Write-Host '========================================='",
            "",
            "Write-Host 'Testing DNS resolution...'",
            "nslookup update.microsoft.com",
            "nslookup download.windowsupdate.com",
            "",
            "Write-Host 'Testing connectivity to Microsoft Update servers...'",
            "Test-NetConnection update.microsoft.com -Port 443 -InformationLevel Detailed",
            "Test-NetConnection download.windowsupdate.com -Port 443 -InformationLevel Detailed",
            "",
            "Write-Host 'Checking Windows Update service status...'",
            "Get-Service wuauserv | Format-List *",
            "",
            "Write-Host 'Testing general internet connectivity...'",
            "Test-NetConnection google.com -Port 443",
            "",
            "Write-Host '========================================='",
            "Write-Host 'Network test complete. Waiting before updates...'",
            "Write-Host '========================================='",
            "Start-Sleep -Seconds 30"
        ]
    }

    # Prepare Windows Update service
    provisioner "powershell" {
        inline = [
            "Write-Host 'Configuring Windows Update service...'",
            "Stop-Service wuauserv -Force -ErrorAction SilentlyContinue",
            "Start-Sleep -Seconds 5",
            "Start-Service wuauserv",
            "Set-Service wuauserv -StartupType Manual",
            "",
            "Write-Host 'Waiting for Windows Update to initialize...'",
            "Start-Sleep -Seconds 60"
        ]
    }

    # Windows updates
    provisioner "windows-update" {
        search_criteria = "IsInstalled=0"
        update_limit = 25
        filters = [
            "exclude:$_.Title -like '*Preview*'",
            "include:$true"
        ]
    }

    provisioner "powershell" {
        script = "./data2/phase-5d.windows-compress.ps1"
    }

 #   provisioner "powershell" {
 #       script = "./data2/phase-5d.windows-compress.ps1"
 #   }

    provisioner "file" {
        source      = "./data2/unattend.xml"
        destination = "C:\\Windows\\System32\\Sysprep\\unattend.xml"
    }

    provisioner "powershell" {
        inline = [
            "C:\\Windows\\System32\\Sysprep\\sysprep.exe /oobe /generalize /quit /quiet /unattend:C:\\Windows\\System32\\Sysprep\\unattend.xml"
        ]
    }
}

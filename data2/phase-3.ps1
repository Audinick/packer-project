# Phase 3 - environment-specific install: Wireshark, nmap, OpenSSH

param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('true','false','$true','$false','0','1')]
    [boolean]$DebugMode=$false
)

Write-Output "Phase 3 [START] - Start of Phase 3"

$choco_packages = @("wireshark", "nmap", "openssh")
$choco_exit_codes = @(0,1605,1614,1641,3010)
$install_success_count = 0
$install_attempt_max = 10
$goterror = 0

foreach ($package in $choco_packages) {
    $install_success = $false
    $install_attempt = 1

    do {
        try {
            Write-Output "Phase 3 [INFO] - Installing $package (attempt $install_attempt of $install_attempt_max)"
            choco upgrade $package -y --no-progress --limit-output
            Write-Output "Phase 3 [INFO] - $package install exit code: $LASTEXITCODE"
            if ($choco_exit_codes -contains $LASTEXITCODE) {
                $install_success = $true
                $install_success_count++
                Write-Output "Phase 3 [INFO] - $package installed successfully."
            } else {
                $goterror = 1
            }
        }
        catch {
            Write-Output "Phase 3 [INFO] - $package install retry $install_attempt of $install_attempt_max"
        }
        $install_attempt++
    }
    until ($install_attempt -gt $install_attempt_max -or $install_success)
}

if ($install_success_count -ne $choco_packages.Count) {
    $goterror = 1
    Write-Output "Phase 3 [ERROR] - Not all packages installed successfully. ($install_success_count of $($choco_packages.Count))"
    exit 1
}

Write-Output "Phase 3 [INFO] - All requested packages installed successfully."
Write-Output "Phase 3 [END] - End of Phase 3"

if ($goterror) {
    Write-Output "Phase 3 [ERROR] - something went wrong"
    exit 1
} else {
    exit 0
}

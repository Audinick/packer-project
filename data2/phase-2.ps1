# Phase 2 - System Baseline Configuration and Placeholder for App Installs
Write-Output "[Phase 2] ====================="
Write-Output "[Phase 2] Script starting"
Write-Output "[Phase 2] Target time zone: Eastern Standard Time"
Write-Output "[Phase 2] Power plan set to: Balanced (GUID: 381b4222-f694-41f0-9685-ff5bb260df2e)"

$goterror=0

Write-Output "[Phase 2] Setting local time zone..."
try {
    Set-TimeZone -Id "Eastern Standard Time" -Verbose
    Write-Output "[Phase 2] Time zone successfully set to Eastern Standard Time"
}
catch {
    Write-Output "[Phase 2][ERROR] Failed to set time zone: $_"
    $goterror=1
}

Write-Output "[Phase 2] Setting power plan to Balanced..."
try {
    powercfg.exe /s 381b4222-f694-41f0-9685-ff5bb260df2e
    Write-Output "[Phase 2] Power plan set to Balanced successfully"
}
catch {
    Write-Output "[Phase 2][ERROR] Failed to set power plan: $_"
    $goterror=1
}

# Write-Output "[Phase 2] Chocolatey and app install section is currently disabled (placeholder only)"
# --- BEGIN PLACEHOLDER FOR CHOCO & APP INSTALLS ---
# if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
#     # Chocolatey install logic
# }
# $packages=@("sysinternals")
# $packages_count=$packages.Count
# $packages_attempt_max=10
# $packages_exit_codes=@(0,1605,1614,1641,3010)
# choco feature enable -n allowEmptyChecksums
# choco feature enable -name=usePackageExitCodes
# foreach ($package in $packages) {
#     # Per-package install and status/retry logic
# }
# --- END PLACEHOLDER ---

Write-Output "[Phase 2] Final error flag status: $goterror"
if ($goterror) {
    Write-Output "[Phase 2][ERROR] At least one setup step failed—exiting with error"
    exit 1
}
else {
    Write-Output "[Phase 2] Script completed successfully"
    exit 0
}

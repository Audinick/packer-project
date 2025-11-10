Write-Output "Phase-5d [START] - Cleaning/zeroing/compacting"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Clean WU downloads
try {
    Stop-Service -Name wuauserv -Force -Verbose -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 10
    Stop-Service -Name cryptsvc -Force -Verbose -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 10
    if (Test-Path -Path "$env:systemroot\SoftwareDistribution\Download" ) {
        Write-Output "Phase-5d [INFO]: Cleaning updates.."
        Remove-Item "$env:systemroot\SoftwareDistribution\Download\*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue
    }
    if (Test-Path -Path "$env:systemroot\Prefetch") {
        Write-Output "Phase-5d [INFO]: Cleaning prefetch.."
        Remove-Item "$env:systemroot\Prefetch\*.*" -Recurse -Force -Verbose -ErrorAction SilentlyContinue
    }
}
catch {
    Write-Output "Phase-5d [WARN]: Cleaning failed.."
}

# Disable Windows Error Reporting
Disable-WindowsErrorReporting -ErrorAction SilentlyContinue

# Remove event logs with robust error handling
Write-Output "Phase-5d [INFO]: Clearing Windows event logs..."
foreach ($log in wevtutil el) {
    $result = wevtutil cl "$log" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Output "[Cleanup] Could not clear $log : $result"
    } else {
        Write-Output "[Cleanup] Cleared log: $log"
    }
}

# resetbase/thin winsxs
dism /online /cleanup-image /StartComponentCleanup /ResetBase
dism /online /cleanup-Image /SPSuperseded

# Remove leftovers from deploy
if ((Test-Path -Path "$env:systemroot\Temp") -and ("$env:systemroot")) {
    Write-Output "Phase-5d [INFO]: Cleaning TEMP"
    Remove-Item $env:systemroot\Temp\* -Exclude "packer-*","script-*" -Recurse -Force -ErrorAction SilentlyContinue
}

# optimize disk
Write-Output "Phase-5d [INFO] Defragging.."
if (Get-Command Optimize-Volume -ErrorAction SilentlyContinue) {
    Optimize-Volume -DriveLetter C -Defrag -verbose
} else {
    Defrag.exe c: /H
}

# Zero free space for compacting
Write-Output "Phase-5d [INFO] Zeroing out empty space..."
$startDTM = (Get-Date)
$FilePath = "c:\zero.tmp"
$Volume = Get-WmiObject win32_logicaldisk -filter "DeviceID='C:'"
$ArraySize = 4096kb
$SpaceToLeave = $Volume.Size * 0.001
$FileSize = $Volume.FreeSpace - $SpaceToLeave
$ZeroArray = New-Object byte[] $ArraySize
$Stream = [io.File]::OpenWrite($FilePath)
try {
    $CurFileSize = 0
    while ($CurFileSize -lt $FileSize) {
        $Stream.Write($ZeroArray, 0, $ZeroArray.Length)
        $CurFileSize += $ZeroArray.Length
    }
}
finally {
    if ($Stream) {
        $Stream.Close()
    }
}
Remove-Item $FilePath -Recurse -Force -ErrorAction SilentlyContinue
$endDTM = (Get-Date)
Write-Output "Phase 5d [INFO] Zeroing took: $(($endDTM-$startDTM).totalseconds) seconds"

Write-Output "Phase-5d [END]"

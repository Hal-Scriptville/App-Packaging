<#
.SYNOPSIS
    Intune custom detection script — confirms network printer is installed.

.DESCRIPTION
    Called by Intune to determine whether the Win32 app is present.
    Reads config.json from the same directory as this script.

    Exit 0 + stdout output = Detected (app considered installed)
    Exit 1 / empty stdout  = Not detected (Intune will attempt install)

.NOTES
    Detection rule in Intune:
        Type: Custom script
        Script: Detect-NetworkPrinter.ps1
        Run as 32-bit: No
#>

$ErrorActionPreference = "SilentlyContinue"

$configPath = Join-Path $PSScriptRoot "config.json"
if (-not (Test-Path $configPath)) { exit 1 }

try {
    $config      = Get-Content $configPath -Raw | ConvertFrom-Json
    $PrinterUNC  = $config.PrinterUNC
    $PrinterName = $config.PrinterName
} catch { exit 1 }

# Primary check: printer exists by friendly name
$byName = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
if ($byName) {
    Write-Host "Detected: $PrinterName"
    exit 0
}

# Fallback: printer exists under the share name (rename may not have applied)
$shareName = $PrinterUNC.TrimStart('\').Split('\')[-1]
$byShare   = Get-Printer -Name $shareName -ErrorAction SilentlyContinue
if ($byShare) {
    Write-Host "Detected: $shareName (pending rename)"
    exit 0
}

# Not found
exit 1

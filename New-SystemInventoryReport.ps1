<#
.SYNOPSIS
    Windows System Inventory & Backup-Readiness Report Generator.

.DESCRIPTION
    Scans the local machine for installed desktop applications, Microsoft Store
    apps, drivers, runtimes/frameworks, and a curated list of configuration
    files/settings that are easy to forget when reinstalling Windows or moving
    to a new PC. Produces a single Markdown report with tables and brief
    explanations.

.PARAMETER OutputPath
    Folder where the .md report will be saved. Defaults to a "reports"
    folder inside the script's own directory.

.EXAMPLE
    .\New-SystemInventoryReport.ps1
    .\New-SystemInventoryReport.ps1 -OutputPath C:\Temp

.NOTES
    - Run from an elevated ("Run as Administrator") PowerShell window for the
      most complete driver and Store-app data. It still works without
      elevation, just with a few gaps.
    - If script execution is blocked, run:
        powershell -ExecutionPolicy Bypass -File .\New-SystemInventoryReport.ps1
#>

[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'reports')
)

$ErrorActionPreference = 'SilentlyContinue'
Import-Module (Join-Path $PSScriptRoot 'Inventory.psm1') -Force
$null = New-Item -ItemType Directory -Path $OutputPath -Force

$ReportDate    = Get-Date
$Stamp         = $ReportDate.ToString('yyyy-MM-dd_HHmm')
$ReportFile    = Join-Path $OutputPath "SystemInventory_$Stamp.md"
$ComputerName  = $env:COMPUTERNAME
$IsAdmin       = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$OSInfo        = Get-CimInstance Win32_OperatingSystem

Write-Host "Generating system inventory report for $ComputerName..." -ForegroundColor Cyan
if (-not $IsAdmin) {
    Write-Host "Note: not running elevated - driver/Store-app data may be incomplete." -ForegroundColor Yellow
}

# ----------------------------------------------------------------------------
# Gather data
# ----------------------------------------------------------------------------
$Programs    = Get-InstalledPrograms
$Runtimes    = Get-RuntimePrograms -Programs $Programs
$AppPrograms = Get-AppPrograms -Programs $Programs
$StoreApps   = Get-StoreApps
$Drivers     = Get-DriverList
$ConfigItems = Get-ConfigItems

$WifiProfiles    = Get-WifiProfiles
$ScheduledTasks  = Get-NonMicrosoftScheduledTasks
$BrowserProfiles = Get-BrowserProfiles
$Printers        = Get-InventoryPrinters
$FirewallRules   = Get-CustomFirewallRules

# ----------------------------------------------------------------------------
# Build the Markdown report
# ----------------------------------------------------------------------------
$md = New-Object System.Collections.Generic.List[string]

$md.Add('# Windows System Inventory Report')
$md.Add('')
$md.Add("**Computer:** $ComputerName  ")
$md.Add("**Generated:** $($ReportDate.ToString('yyyy-MM-dd HH:mm'))  ")
$md.Add("**OS:** $($OSInfo.Caption) (Build $($OSInfo.BuildNumber))  ")
$md.Add("**Elevated session:** $IsAdmin")
$md.Add('')
$md.Add('> This report lists installed software, drivers, and runtimes, and flags configuration files/settings that should be backed up before reinstalling Windows or migrating to a new machine.')
$md.Add('')
$md.Add('---')
$md.Add('')
$md.Add('## Summary')
$md.Add('')
$md.Add('| Category | Count |')
$md.Add('| --- | --- |')
$md.Add("| Installed applications | $($AppPrograms.Count) |")
$md.Add("| Runtimes & frameworks | $($Runtimes.Count) |")
$md.Add("| Microsoft Store apps | $($StoreApps.Count) |")
$md.Add("| Drivers | $($Drivers.Count) |")
$md.Add("| Saved Wi-Fi networks | $($WifiProfiles.Count) |")
$md.Add("| Active non-Microsoft scheduled tasks | $($ScheduledTasks.Count) |")
$md.Add("| Custom firewall rules | $($FirewallRules.Count) |")
$md.Add('')
$md.Add('---')
$md.Add('')
$md.Add('## 1. Installed Applications')
$md.Add('')
$md.Add('Desktop applications detected via the Windows uninstall registry keys.')
$md.Add('')
$AppWithNote = $AppPrograms | Select-Object Name, Version, Publisher, InstallDate, @{n = 'Notes'; e = { Get-SoftwareNote $_.Name } }
$md.Add((ConvertTo-MarkdownTable -InputObject $AppWithNote))
$md.Add('')
$md.Add('## 2. Runtimes & Frameworks')
$md.Add('')
$md.Add("Shared runtimes/redistributables other software depends on. These are generally re-downloadable - the linked environment settings (PATH, packages) are what's actually worth backing up; see Section 4.")
$md.Add('')
$RuntimeWithNote = $Runtimes | Select-Object Name, Version, Publisher, @{n = 'What it is / backup note'; e = { Get-SoftwareNote $_.Name } }
$md.Add((ConvertTo-MarkdownTable -InputObject $RuntimeWithNote))
$md.Add('')
$md.Add('## 3. Microsoft Store Apps')
$md.Add('')
$md.Add((ConvertTo-MarkdownTable -InputObject $StoreApps))
$md.Add('')
$md.Add('## 4. Installed Drivers')
$md.Add('')
$md.Add("Signed drivers reported by Windows. The driver files themselves don't need backing up (Windows Update or the vendor site resupplies them); recording manufacturer/version is mainly useful for matching hardware after a clean install.")
$md.Add('')
$md.Add((ConvertTo-MarkdownTable -InputObject $Drivers))
$md.Add('')
$md.Add('---')
$md.Add('')
$md.Add('## 5. Configurations to Back Up')
$md.Add('')
$md.Add('These are the files, settings, and locations most likely to hold irreplaceable personal configuration. Items marked `No` were not found at the checked path on this profile and can be skipped.')
$md.Add('')
$md.Add((ConvertTo-MarkdownTable -InputObject ($ConfigItems | Select-Object Item, Location, Found, Explanation)))
$md.Add('')
$md.Add('### 5a. Saved Wi-Fi Profiles')
$md.Add('')
if ($WifiProfiles.Count -gt 0) {
    foreach ($w in $WifiProfiles) { $md.Add("- $w") }
} else {
    $md.Add('_None found, or netsh unavailable._')
}
$md.Add('')
$md.Add('_Export keys with:_ ``netsh wlan export profile key=clear folder=.\WifiBackup``')
$md.Add('')
$md.Add('### 5b. Active Non-Microsoft Scheduled Tasks')
$md.Add('')
$md.Add((ConvertTo-MarkdownTable -InputObject $ScheduledTasks))
$md.Add('')
$md.Add('### 5c. Browser Profile Folders')
$md.Add('')
$md.Add((ConvertTo-MarkdownTable -InputObject $BrowserProfiles))
$md.Add('')
$md.Add('### 5d. Printers')
$md.Add('')
$md.Add((ConvertTo-MarkdownTable -InputObject $Printers))
$md.Add('')
$md.Add('### 5e. Custom Firewall Rules')
$md.Add('')
$md.Add('_Heuristic: rules not assigned to a built-in rule group. Review before assuming all are user-added._')
$md.Add('')
$md.Add((ConvertTo-MarkdownTable -InputObject $FirewallRules))
$md.Add('')
$md.Add('---')
$md.Add('')
$md.Add('## Recommended Backup Checklist')
$md.Add('')
$md.Add('- [ ] Export browser bookmarks/passwords, or confirm account sync is enabled')
$md.Add('- [ ] Copy ``.ssh``, ``.gitconfig``, and any API keys/tokens')
$md.Add('- [ ] Export WSL distros: ``wsl --export <Distro> backup.tar``')
$md.Add('- [ ] Export Wi-Fi profiles with keys')
$md.Add('- [ ] Save VS Code settings + ``code --list-extensions > extensions.txt``')
$md.Add('- [ ] Record license keys for paid software (Office, Adobe, games)')
$md.Add('- [ ] Note mapped drives and printer names/ports')
$md.Add('- [ ] Export custom scheduled tasks: ``Get-ScheduledTask | Export-ScheduledTask``')
$md.Add('- [ ] Keep this report for reference when reinstalling')
$md.Add('')

($md -join "`n") | Out-File -FilePath $ReportFile -Encoding utf8

Write-Host ""
Write-Host "Report saved to: $ReportFile" -ForegroundColor Green

<#
.SYNOPSIS
    Shared scanning/helper functions for the system-pkgs-checker tools.

.DESCRIPTION
    Used by both New-SystemInventoryReport.ps1 (Markdown report) and
    SystemInventoryGUI.ps1 (interactive WPF GUI) so the scanning logic and
    known-software notes stay in one place.
#>

# Known-software description lookup (regex key -> brief explanation / backup note)
$script:KnownDescriptions = [ordered]@{
    '\.NET'                = 'Microsoft runtime needed to run .NET apps. Reinstallable from Microsoft; no personal data to back up.'
    'Visual C\+\+'         = 'Visual C++ Redistributable runtime libraries many apps depend on. No data to back up.'
    'Java'                 = 'Java Runtime/Development Kit. Back up JAVA_HOME / PATH environment entries if customized.'
    'Python'               = 'Python interpreter. Back up virtual environments and installed packages (pip freeze > requirements.txt).'
    'Node\.js'              = 'JavaScript runtime. Back up global npm packages (npm list -g) and .npmrc.'
    'Docker'               = 'Container runtime. Back up Docker Desktop settings, volumes, and compose files.'
    '^Git( |$)'             = 'Version control client. Back up ~/.gitconfig, SSH keys, and stored credentials.'
    'Windows Subsystem for Linux|WSL' = 'Linux compatibility layer. Export each distro with "wsl --export" before reinstalling Windows.'
    'Visual Studio Code'   = 'Code editor. Back up settings.json, keybindings.json, snippets, and extension list.'
    'Steam'                = 'Game launcher. Games re-download from the cloud; back up local save files not covered by Steam Cloud.'
    'Adobe'                = 'Adobe app. Record license/activation details and export custom presets/preferences.'
    'Microsoft Office|Outlook' = 'Office suite. Back up custom templates/macros and Outlook PST/OST data files.'
    'OneDrive'             = 'Cloud sync client. Confirm sync is fully up to date before treating local files as backed up.'
    'Dropbox'              = 'Cloud sync client. Confirm sync is fully up to date before treating local files as backed up.'
    '7-Zip|WinRAR'          = 'Archive utility. No personal data; file-type associations reset after reinstall.'
    'VLC'                  = 'Media player. No personal data beyond saved playlists.'
    'PowerToys'            = 'Microsoft productivity utilities. Export settings via PowerToys Settings > General > Backup.'
    'DirectX'              = 'Graphics/multimedia runtime, normally bundled with Windows Update. Nothing to back up.'
    'Redistributable|SDK|Runtime|Framework' = 'Supporting runtime/SDK for other software. Generally re-downloadable; check for linked project configs.'
}

$script:RuntimePatterns = '\.NET|Visual C\+\+|^Java|Python|Node\.js|Docker|^Git( |$)|WSL|Subsystem for Linux|DirectX|Redistributable|Runtime|SDK|Framework'

function Get-SoftwareNote {
    param([string]$Name)
    if (-not $Name) { return '' }
    foreach ($pattern in $script:KnownDescriptions.Keys) {
        if ($Name -match $pattern) { return $script:KnownDescriptions[$pattern] }
    }
    return ''
}

function Test-PathExists {
    param([string]$Path)
    if ($Path -and (Test-Path $Path)) { 'Yes' } else { 'No' }
}

function Test-IsElevated {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ConvertTo-MarkdownTable {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [object[]]$InputObject,
        [string[]]$Columns
    )
    begin { $rows = @() }
    process { if ($InputObject) { $rows += $InputObject } }
    end {
        if (-not $rows -or $rows.Count -eq 0) { return "_No data found._" }
        if (-not $Columns) { $Columns = $rows[0].PSObject.Properties.Name }
        $header = "| " + ($Columns -join ' | ') + " |"
        $sep    = "| " + (($Columns | ForEach-Object { '---' }) -join ' | ') + " |"
        $lines  = foreach ($row in $rows) {
            $cells = foreach ($c in $Columns) {
                $val = $row.$c
                if ($null -eq $val -or $val -eq '') { ' ' }
                else { (([string]$val) -replace '\|', '\|') -replace "`r?`n", ' ' }
            }
            "| " + ($cells -join ' | ') + " |"
        }
        ($header, $sep, ($lines -join "`n")) -join "`n"
    }
}

function Get-InstalledPrograms {
    $paths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and -not $_.SystemComponent } |
        Select-Object -Property `
            @{n = 'Name'; e = { $_.DisplayName } },
            @{n = 'Version'; e = { $_.DisplayVersion } },
            @{n = 'Publisher'; e = { $_.Publisher } },
            @{n = 'InstallDate'; e = {
                    if ($_.InstallDate -match '^\d{8}$') {
                        [datetime]::ParseExact($_.InstallDate, 'yyyyMMdd', $null).ToString('yyyy-MM-dd')
                    } else { $_.InstallDate }
                } } |
        Sort-Object Name -Unique
}

function Get-RuntimePrograms {
    param([Parameter(Mandatory)][object[]]$Programs)
    $Programs | Where-Object { $_.Name -match $script:RuntimePatterns }
}

function Get-AppPrograms {
    param([Parameter(Mandatory)][object[]]$Programs)
    $Programs | Where-Object { $_.Name -notmatch $script:RuntimePatterns }
}

function Get-StoreApps {
    # -AllUsers requires an elevated session; it throws a terminating
    # UnauthorizedAccessException (not suppressed by -ErrorAction) when run
    # standard, so only request it when actually running as Administrator.
    $isAdmin = Test-IsElevated
    try {
        if ($isAdmin) {
            $packages = Get-AppxPackage -AllUsers -ErrorAction Stop
        } else {
            $packages = Get-AppxPackage -ErrorAction Stop
        }
    } catch {
        $packages = @()
    }
    $packages |
        Where-Object { -not $_.IsFramework -and -not $_.IsResourcePackage } |
        Select-Object -Property `
            @{n = 'Name'; e = { $_.Name } },
            @{n = 'Version'; e = { $_.Version } },
            @{n = 'Publisher'; e = { $_.Publisher } } |
        Sort-Object Name -Unique
}

function Get-DriverList {
    Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
        Where-Object { $_.DeviceName } |
        Select-Object -Property `
            @{n = 'Device'; e = { $_.DeviceName } },
            @{n = 'Manufacturer'; e = { $_.Manufacturer } },
            @{n = 'Version'; e = { $_.DriverVersion } },
            @{n = 'DriverDate'; e = {
                    if ($_.DriverDate) {
                        try { [Management.ManagementDateTimeConverter]::ToDateTime($_.DriverDate).ToString('yyyy-MM-dd') }
                        catch { '' }
                    }
                } } |
        Sort-Object Device -Unique
}

function Get-WifiProfiles {
    (netsh wlan show profiles) 2>$null |
        Select-String 'All User Profile' |
        ForEach-Object { ($_ -split ':', 2)[1].Trim() }
}

function Get-NonMicrosoftScheduledTasks {
    Get-ScheduledTask -ErrorAction SilentlyContinue |
        Where-Object { $_.TaskPath -notmatch '\\Microsoft\\' -and $_.State -ne 'Disabled' } |
        Select-Object TaskName, TaskPath, State
}

function Get-BrowserProfiles {
    $found = @()
    $bp = @{
        Chrome  = "$env:LOCALAPPDATA\Google\Chrome\User Data"
        Edge    = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
        Firefox = "$env:APPDATA\Mozilla\Firefox\Profiles"
        Brave   = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
    }
    foreach ($name in $bp.Keys) {
        if (Test-Path $bp[$name]) { $found += [PSCustomObject]@{ Browser = $name; Path = $bp[$name] } }
    }
    $found
}

function Get-InventoryPrinters {
    Get-Printer -ErrorAction SilentlyContinue | Select-Object Name, DriverName, PortName
}

function Get-CustomFirewallRules {
    Get-NetFirewallRule -ErrorAction SilentlyContinue |
        Where-Object { $_.Group -eq '' -and $_.Enabled -eq 'True' } |
        Select-Object DisplayName, Direction, Action
}

<#
.SYNOPSIS
    Returns the list of config items worth backing up, each with an
    'ActionType' the GUI can execute and a 'Source' path/identifier it acts on.
    ActionType values: CopyFile, CopyFolder, WslExport, WifiExport,
    ScheduledTaskExport, EnvVarsExport, Manual (no automated action available).
#>
function Get-ConfigItems {
    $items = @()

    $items += [PSCustomObject]@{ Item = 'SSH keys & config'; Location = "$env:USERPROFILE\.ssh"; Found = Test-PathExists "$env:USERPROFILE\.ssh"; Explanation = 'Private/public keys and host configs for SSH/Git access. Losing them means regenerating keys and re-adding them to every server/service.'; ActionType = 'CopyFolder'; Source = "$env:USERPROFILE\.ssh" }
    $items += [PSCustomObject]@{ Item = 'Git global config'; Location = "$env:USERPROFILE\.gitconfig"; Found = Test-PathExists "$env:USERPROFILE\.gitconfig"; Explanation = 'Stores user.name, user.email, aliases, and credential helper settings.'; ActionType = 'CopyFile'; Source = "$env:USERPROFILE\.gitconfig" }
    $items += [PSCustomObject]@{ Item = 'PowerShell profile'; Location = "$PROFILE"; Found = Test-PathExists $PROFILE; Explanation = 'Custom functions, aliases, and module imports loaded at shell startup.'; ActionType = 'CopyFile'; Source = "$PROFILE" }
    $items += [PSCustomObject]@{ Item = 'Windows Terminal settings'; Location = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"; Found = Test-PathExists "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"; Explanation = 'Terminal profiles, color schemes, keybindings, and default shell.'; ActionType = 'CopyFile'; Source = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" }
    $items += [PSCustomObject]@{ Item = 'VS Code user settings'; Location = "$env:APPDATA\Code\User\settings.json"; Found = Test-PathExists "$env:APPDATA\Code\User\settings.json"; Explanation = 'Editor preferences/keybindings. Extension list is exported separately.'; ActionType = 'CopyFile'; Source = "$env:APPDATA\Code\User\settings.json" }
    $items += [PSCustomObject]@{ Item = 'Hosts file'; Location = "$env:WINDIR\System32\drivers\etc\hosts"; Found = Test-PathExists "$env:WINDIR\System32\drivers\etc\hosts"; Explanation = 'Custom DNS/IP hostname mappings, often used for local dev or domain blocking.'; ActionType = 'CopyFile'; Source = "$env:WINDIR\System32\drivers\etc\hosts" }
    $items += [PSCustomObject]@{ Item = 'WSL distributions'; Location = '(wsl --export)'; Found = if (Get-Command wsl -ErrorAction SilentlyContinue) { 'Installed' } else { 'Not installed' }; Explanation = 'Linux distros with their packages/files. Exported as a .tar per distro.'; ActionType = 'WslExport'; Source = '' }
    $items += [PSCustomObject]@{ Item = 'Saved Wi-Fi profiles'; Location = '(netsh wlan export profile)'; Found = if ((Get-WifiProfiles).Count -gt 0) { 'Yes' } else { 'No' }; Explanation = 'Saved wireless network names/passwords, exported with keys in clear text.'; ActionType = 'WifiExport'; Source = '' }
    $items += [PSCustomObject]@{ Item = 'User environment variables'; Location = 'HKCU:\Environment'; Found = 'Always present'; Explanation = 'Custom PATH entries and variables (e.g. JAVA_HOME, PYTHONPATH) tools rely on.'; ActionType = 'EnvVarsExport'; Source = '' }
    $items += [PSCustomObject]@{ Item = 'Non-Microsoft scheduled tasks'; Location = 'Task Scheduler Library'; Found = if ((Get-NonMicrosoftScheduledTasks).Count -gt 0) { 'Yes' } else { 'No' }; Explanation = 'Custom automation (backups, scripts) that is easy to forget and lose on reinstall.'; ActionType = 'ScheduledTaskExport'; Source = '' }
    $items += [PSCustomObject]@{ Item = 'Browser profile folders'; Location = 'Chrome/Edge/Firefox/Brave profile paths'; Found = if ((Get-BrowserProfiles).Count -gt 0) { 'Yes' } else { 'No' }; Explanation = 'Bookmarks, saved passwords, extensions, history - relevant if not already synced to an account. Files locked by a running browser are skipped automatically.'; ActionType = 'BrowserProfilesExport'; Source = '' }
    $items += [PSCustomObject]@{ Item = 'Printers'; Location = '(Get-Printer)'; Found = if ((Get-InventoryPrinters).Count -gt 0) { 'Yes' } else { 'No' }; Explanation = 'Installed printers/ports. Drivers may need reinstalling, but names/ports are exported to a CSV for reference.'; ActionType = 'PrintersExport'; Source = '' }
    $items += [PSCustomObject]@{ Item = 'Custom firewall rules'; Location = '(Get-NetFirewallRule)'; Found = if ((Get-CustomFirewallRules).Count -gt 0) { 'Yes' } else { 'No' }; Explanation = 'Manually added inbound/outbound rules for apps, games, or dev servers, exported to a CSV for reference.'; ActionType = 'FirewallRulesExport'; Source = '' }
    $items += [PSCustomObject]@{ Item = 'Driver packages'; Location = '(Export-WindowsDriver -Online)'; Found = if (Test-IsElevated) { 'Yes' } else { 'Needs elevation' }; Explanation = 'Exports all non-Microsoft (third-party) driver packages via DISM so they can be reinstalled with pnputil after a clean Windows install. Requires running this GUI as Administrator.'; ActionType = 'DriverExport'; Source = '' }

    $items
}

Export-ModuleMember -Function Get-SoftwareNote, Test-PathExists, Test-IsElevated, ConvertTo-MarkdownTable, `
    Get-InstalledPrograms, Get-RuntimePrograms, Get-AppPrograms, Get-StoreApps, Get-DriverList, `
    Get-WifiProfiles, Get-NonMicrosoftScheduledTasks, Get-BrowserProfiles, Get-InventoryPrinters, `
    Get-CustomFirewallRules, Get-ConfigItems

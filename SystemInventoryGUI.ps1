<#
.SYNOPSIS
    Interactive WPF GUI for the Windows system inventory / backup-readiness scan.

.DESCRIPTION
    WinUtil-style native window: tabs for Applications, Runtimes, Store Apps,
    Drivers, and Configs to Back Up. The Configs tab lets you check items and
    actually run the backup action (copy files/folders, export WSL distros,
    export Wi-Fi profiles, export env vars, export scheduled tasks) into a
    folder you choose. Uses the same scanning logic as
    New-SystemInventoryReport.ps1 via Inventory.psm1.

.EXAMPLE
    .\SystemInventoryGUI.ps1

.NOTES
    Run elevated for the most complete driver/Store-app data.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'SilentlyContinue'
Import-Module (Join-Path $PSScriptRoot 'Inventory.psm1') -Force

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ----------------------------------------------------------------------------
# XAML layout
# ----------------------------------------------------------------------------
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="System Inventory &amp; Backup" Height="720" Width="1400"
        WindowStartupLocation="CenterScreen"
        Background="{DynamicResource WindowBackgroundBrush}"
        FontFamily="MesloLGS Nerd Font, Consolas" FontWeight="Medium">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="{DynamicResource ButtonBackgroundBrush}"/>
            <Setter Property="Foreground" Value="{DynamicResource ButtonForegroundBrush}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource BorderColorBrush}"/>
            <Setter Property="Padding" Value="6,3"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="1" CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Bd" Property="BorderBrush" Value="{DynamicResource AccentBrush}"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="Bd" Property="Background" Value="{DynamicResource ControlBackgroundBrush}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="{DynamicResource ControlBackgroundBrush}"/>
            <Setter Property="Foreground" Value="{DynamicResource ControlForegroundBrush}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource BorderColorBrush}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="1" CornerRadius="6">
                            <ScrollViewer x:Name="PART_ContentHost" Margin="6,3"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ComboBoxItem">
            <Setter Property="Background" Value="{DynamicResource ControlBackgroundBrush}"/>
            <Setter Property="Foreground" Value="{DynamicResource ControlForegroundBrush}"/>
            <Setter Property="Padding" Value="6,4"/>
            <Style.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter Property="Background" Value="{DynamicResource AccentBrush}"/>
                    <Setter Property="Foreground" Value="{DynamicResource PanelBackgroundBrush}"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="ComboBox">
            <Setter Property="Background" Value="{DynamicResource ControlBackgroundBrush}"/>
            <Setter Property="Foreground" Value="{DynamicResource ControlForegroundBrush}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource BorderColorBrush}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton Name="ToggleButton"
                                          Background="{TemplateBinding Background}"
                                          BorderBrush="{TemplateBinding BorderBrush}"
                                          IsChecked="{Binding Path=IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                                          ClickMode="Press" Focusable="False">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="ToggleButton">
                                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="6">
                                            <Grid>
                                                <Grid.ColumnDefinitions>
                                                    <ColumnDefinition/>
                                                    <ColumnDefinition Width="20"/>
                                                </Grid.ColumnDefinitions>
                                                <Path Grid.Column="1" Data="M0,0 L4,4 L8,0 Z" Fill="{DynamicResource ControlForegroundBrush}"
                                                      HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                            </Grid>
                                        </Border>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <TextBlock Name="ContentSite" IsHitTestVisible="False"
                                       Text="{Binding Path=SelectedItem.Name, RelativeSource={RelativeSource TemplatedParent}}"
                                       Foreground="{DynamicResource ControlForegroundBrush}"
                                       Margin="6,0,24,0" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                            <Popup Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}"
                                   AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                                <Border Name="DropDownBorder" Background="{DynamicResource ControlBackgroundBrush}"
                                        BorderBrush="{DynamicResource BorderColorBrush}" BorderThickness="1" CornerRadius="6"
                                        MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}"
                                        MaxHeight="220">
                                    <ScrollViewer SnapsToDevicePixels="True">
                                        <ItemsPresenter/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="{DynamicResource ControlForegroundBrush}"/>
        </Style>
        <Style TargetType="TabControl">
            <Setter Property="Background" Value="{DynamicResource PanelBackgroundBrush}"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="0,4,0,0"/>
        </Style>
        <Style TargetType="TabItem">
            <Setter Property="Foreground" Value="{DynamicResource ControlForegroundBrush}"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border Name="Border" BorderBrush="{DynamicResource BorderColorBrush}" BorderThickness="1,1,1,0"
                                Background="{DynamicResource PanelBackgroundBrush}" Margin="0,0,2,0" Padding="10,5" CornerRadius="6,6,0,0">
                            <ContentPresenter ContentSource="Header" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="{DynamicResource ControlBackgroundBrush}"/>
                                <Setter Property="Foreground" Value="{DynamicResource AccentBrush}"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="{DynamicResource ButtonBackgroundBrush}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="DataGrid">
            <Setter Property="Background" Value="{DynamicResource GridBackgroundBrush}"/>
            <Setter Property="RowBackground" Value="{DynamicResource GridRowBackgroundBrush}"/>
            <Setter Property="AlternatingRowBackground" Value="{DynamicResource GridAltRowBackgroundBrush}"/>
            <Setter Property="Foreground" Value="{DynamicResource GridForegroundBrush}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource BorderColorBrush}"/>
            <Setter Property="HorizontalGridLinesBrush" Value="{DynamicResource BorderColorBrush}"/>
            <Setter Property="VerticalGridLinesBrush" Value="{DynamicResource BorderColorBrush}"/>
            <Setter Property="HeadersVisibility" Value="Column"/>
        </Style>
        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Background" Value="{DynamicResource GridHeaderBackgroundBrush}"/>
            <Setter Property="Foreground" Value="{DynamicResource GridHeaderForegroundBrush}"/>
        </Style>
        <Style TargetType="DataGridCell">
            <Setter Property="Foreground" Value="{DynamicResource GridForegroundBrush}"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderBrush" Value="Transparent"/>
            <Style.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="{DynamicResource ButtonBackgroundBrush}"/>
                    <Setter Property="BorderBrush" Value="{DynamicResource AccentBrush}"/>
                    <Setter Property="Foreground" Value="{DynamicResource GridForegroundBrush}"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style x:Key="ThemedCheckBoxStyle" TargetType="CheckBox">
            <Setter Property="Background" Value="{DynamicResource ControlBackgroundBrush}"/>
            <Setter Property="Foreground" Value="{DynamicResource ControlForegroundBrush}"/>
            <Setter Property="HorizontalAlignment" Value="Center"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                            <Border Name="Box" Width="14" Height="14" VerticalAlignment="Center"
                                    BorderBrush="{DynamicResource BorderColorBrush}" BorderThickness="1" CornerRadius="3"
                                    Background="{DynamicResource ControlBackgroundBrush}">
                                <Path Name="CheckMark" Data="M 1.5,5 L 5,8.5 L 11,1.5" Stroke="{DynamicResource AccentBrush}"
                                      StrokeThickness="2" Visibility="Collapsed" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                            </Border>
                            <ContentPresenter Margin="6,0,0,0" VerticalAlignment="Center"/>
                        </StackPanel>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="CheckMark" Property="Visibility" Value="Visible"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Box" Property="BorderBrush" Value="{DynamicResource AccentBrush}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="{DynamicResource PanelBackgroundBrush}"/>
            <Setter Property="Width" Value="14"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Grid Background="{DynamicResource PanelBackgroundBrush}">
                            <Track Name="PART_Track" IsDirectionReversed="True">
                                <Track.DecreaseRepeatButton>
                                    <RepeatButton Command="ScrollBar.LineUpCommand" Width="0" Height="0" Opacity="0"/>
                                </Track.DecreaseRepeatButton>
                                <Track.IncreaseRepeatButton>
                                    <RepeatButton Command="ScrollBar.LineDownCommand" Width="0" Height="0" Opacity="0"/>
                                </Track.IncreaseRepeatButton>
                                <Track.Thumb>
                                    <Thumb>
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb">
                                                <Border Background="{DynamicResource ButtonBackgroundBrush}" CornerRadius="3" Margin="2"/>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="Orientation" Value="Horizontal">
                    <Setter Property="Width" Value="Auto"/>
                    <Setter Property="Height" Value="14"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>
    <DockPanel LastChildFill="True">

        <StackPanel DockPanel.Dock="Top" Orientation="Horizontal" Margin="8"
                    Background="{DynamicResource PanelBackgroundBrush}">
            <Button Name="BtnRescan" Content="Scan" Width="90" Margin="0,0,8,0"/>
            <TextBlock Text="Theme:" VerticalAlignment="Center" Margin="0,0,4,0"/>
            <ComboBox Name="CmbTheme" Width="140" Margin="0,0,16,0" DisplayMemberPath="Name"/>
            <TextBlock Text="Backup folder:" VerticalAlignment="Center" Margin="0,0,4,0"/>
            <TextBox Name="TxtBackupFolder" Width="360" Margin="0,0,4,0"/>
            <Button Name="BtnBrowse" Content="Browse..." Width="80" Margin="0,0,16,0"/>
            <Button Name="BtnBackupSelected" Content="Backup Selected" Width="120" Margin="0,0,8,0"/>
            <Button Name="BtnExportReport" Content="Export Report" Width="110"/>
        </StackPanel>

        <TextBox Name="TxtLog" DockPanel.Dock="Bottom" Height="120" Margin="8"
                  IsReadOnly="True" VerticalScrollBarVisibility="Auto"
                  TextWrapping="Wrap" FontSize="11"
                  Background="{DynamicResource LogBackgroundBrush}"
                  Foreground="{DynamicResource LogForegroundBrush}"/>

        <TabControl Margin="8">
            <TabItem Header="Summary">
                <Border CornerRadius="6" BorderBrush="{DynamicResource BorderColorBrush}" BorderThickness="1" ClipToBounds="True">
                    <Grid Name="GridSummary" Margin="12" Background="{DynamicResource PanelBackgroundBrush}"/>
                </Border>
            </TabItem>
            <TabItem Header="Applications">
                <Border CornerRadius="6" BorderBrush="{DynamicResource BorderColorBrush}" BorderThickness="1" ClipToBounds="True">
                    <DataGrid Name="GridApps" IsReadOnly="True" AutoGenerateColumns="True" Margin="4" BorderThickness="0"/>
                </Border>
            </TabItem>
            <TabItem Header="Runtimes">
                <Border CornerRadius="6" BorderBrush="{DynamicResource BorderColorBrush}" BorderThickness="1" ClipToBounds="True">
                    <DataGrid Name="GridRuntimes" IsReadOnly="True" AutoGenerateColumns="True" Margin="4" BorderThickness="0"/>
                </Border>
            </TabItem>
            <TabItem Header="Store Apps">
                <Border CornerRadius="6" BorderBrush="{DynamicResource BorderColorBrush}" BorderThickness="1" ClipToBounds="True">
                    <DataGrid Name="GridStore" IsReadOnly="True" AutoGenerateColumns="True" Margin="4" BorderThickness="0"/>
                </Border>
            </TabItem>
            <TabItem Header="Drivers">
                <Border CornerRadius="6" BorderBrush="{DynamicResource BorderColorBrush}" BorderThickness="1" ClipToBounds="True">
                    <DataGrid Name="GridDrivers" IsReadOnly="True" AutoGenerateColumns="True" Margin="4" BorderThickness="0"/>
                </Border>
            </TabItem>
            <TabItem Header="Configs to Backup">
                <Border CornerRadius="6" BorderBrush="{DynamicResource BorderColorBrush}" BorderThickness="1" ClipToBounds="True">
                <DataGrid Name="GridConfigs" AutoGenerateColumns="False" Margin="4" CanUserAddRows="False" BorderThickness="0">
                    <DataGrid.Columns>
                        <DataGridCheckBoxColumn Header="Backup" Binding="{Binding Selected, Mode=TwoWay}" Width="60"
                                                 ElementStyle="{StaticResource ThemedCheckBoxStyle}"
                                                 EditingElementStyle="{StaticResource ThemedCheckBoxStyle}"/>
                        <DataGridTextColumn Header="Item" Binding="{Binding Item}" Width="180" IsReadOnly="True"/>
                        <DataGridTextColumn Header="Location" Binding="{Binding Location}" Width="260" IsReadOnly="True"/>
                        <DataGridTextColumn Header="Found" Binding="{Binding Found}" Width="80" IsReadOnly="True"/>
                        <DataGridTextColumn Header="Explanation" Binding="{Binding Explanation}" Width="*" IsReadOnly="True"/>
                    </DataGrid.Columns>
                </DataGrid>
                </Border>
            </TabItem>
        </TabControl>
    </DockPanel>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

$BtnRescan         = $window.FindName('BtnRescan')
$CmbTheme          = $window.FindName('CmbTheme')
$TxtBackupFolder   = $window.FindName('TxtBackupFolder')
$BtnBrowse         = $window.FindName('BtnBrowse')
$BtnBackupSelected = $window.FindName('BtnBackupSelected')
$BtnExportReport   = $window.FindName('BtnExportReport')
$TxtLog            = $window.FindName('TxtLog')
$GridSummary       = $window.FindName('GridSummary')
$GridApps          = $window.FindName('GridApps')
$GridRuntimes      = $window.FindName('GridRuntimes')
$GridStore         = $window.FindName('GridStore')
$GridDrivers       = $window.FindName('GridDrivers')
$GridConfigs       = $window.FindName('GridConfigs')

# ----------------------------------------------------------------------------
# Theme handling
# ----------------------------------------------------------------------------
$ThemesFolder = Join-Path $PSScriptRoot 'themes'
$SettingsFile = Join-Path $PSScriptRoot 'settings.json'

function Get-AvailableThemes {
    Get-ChildItem -Path $ThemesFolder -Filter '*.xaml' -ErrorAction SilentlyContinue |
        ForEach-Object {
            [PSCustomObject]@{
                Name = ($_.BaseName -replace '_', ' ')
                Path = $_.FullName
                Key  = $_.BaseName
            }
        } | Sort-Object Name
}

function Set-Theme {
    param([Parameter(Mandatory)][string]$ThemePath)
    $themeXaml = Get-Content -Path $ThemePath -Raw
    $themeDict = [Windows.Markup.XamlReader]::Parse($themeXaml)
    $window.Resources.MergedDictionaries.Clear()
    $window.Resources.MergedDictionaries.Add($themeDict)
}

function Get-DefaultThemeKey {
    if (Test-Path $SettingsFile) {
        try {
            $settings = Get-Content -Path $SettingsFile -Raw | ConvertFrom-Json
            if ($settings.DefaultTheme) { return $settings.DefaultTheme }
        } catch {}
    }
    return 'boledark'
}

function Save-DefaultThemeKey {
    param([Parameter(Mandatory)][string]$Key)
    [PSCustomObject]@{ DefaultTheme = $Key } | ConvertTo-Json | Out-File -FilePath $SettingsFile -Encoding utf8
}

$AvailableThemes = Get-AvailableThemes
$CmbTheme.ItemsSource = $AvailableThemes
$defaultKey = Get-DefaultThemeKey
$defaultTheme = $AvailableThemes | Where-Object { $_.Key -eq $defaultKey } | Select-Object -First 1
if (-not $defaultTheme) { $defaultTheme = $AvailableThemes | Select-Object -First 1 }
if ($defaultTheme) {
    Set-Theme -ThemePath $defaultTheme.Path
    $CmbTheme.SelectedItem = $defaultTheme
}

$CmbTheme.Add_SelectionChanged({
    if ($CmbTheme.SelectedItem) {
        Set-Theme -ThemePath $CmbTheme.SelectedItem.Path
        Write-Log "Theme switched to $($CmbTheme.SelectedItem.Name)."

        $result = [System.Windows.MessageBox]::Show(
            "Remember '$($CmbTheme.SelectedItem.Name)' as the default theme for next time?",
            'Remember theme',
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question)
        if ($result -eq [System.Windows.MessageBoxResult]::Yes) {
            Save-DefaultThemeKey -Key $CmbTheme.SelectedItem.Key
            Write-Log "Saved '$($CmbTheme.SelectedItem.Name)' as the default theme."
        }
    }
})

$TxtBackupFolder.Text = Join-Path $env:USERPROFILE 'Desktop\SystemBackup'

function Write-Log {
    param([string]$Message)
    $stamp = (Get-Date).ToString('HH:mm:ss')
    $TxtLog.AppendText("[$stamp] $Message`r`n")
    $TxtLog.ScrollToEnd()
}

# ----------------------------------------------------------------------------
# Data containers (script-scope so event handlers can see them)
# ----------------------------------------------------------------------------
$script:Programs    = @()
$script:Runtimes    = @()
$script:AppPrograms = @()
$script:StoreApps   = @()
$script:Drivers     = @()
$script:ConfigItems = @()

function Update-SummaryGrid {
    $GridSummary.Children.Clear()
    $GridSummary.RowDefinitions.Clear()
    $GridSummary.ColumnDefinitions.Clear()
    $null = $GridSummary.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
    $null = $GridSummary.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))

    $rows = @(
        @('Installed applications', $script:AppPrograms.Count),
        @('Runtimes & frameworks',   $script:Runtimes.Count),
        @('Microsoft Store apps',    $script:StoreApps.Count),
        @('Drivers',                 $script:Drivers.Count),
        @('Config items tracked',    $script:ConfigItems.Count)
    )
    for ($i = 0; $i -lt $rows.Count; $i++) {
        $null = $GridSummary.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
        $lbl = New-Object System.Windows.Controls.TextBlock
        $lbl.Text = $rows[$i][0]
        $lbl.FontWeight = 'Bold'
        $lbl.Margin = '0,4,12,4'
        [System.Windows.Controls.Grid]::SetRow($lbl, $i)
        [System.Windows.Controls.Grid]::SetColumn($lbl, 0)
        $val = New-Object System.Windows.Controls.TextBlock
        $val.Text = [string]$rows[$i][1]
        $val.Margin = '0,4,0,4'
        [System.Windows.Controls.Grid]::SetRow($val, $i)
        [System.Windows.Controls.Grid]::SetColumn($val, 1)
        $null = $GridSummary.Children.Add($lbl)
        $null = $GridSummary.Children.Add($val)
    }
}

function Invoke-Scan {
    Write-Log 'Scanning system...'
    $window.Cursor = [System.Windows.Input.Cursors]::Wait

    $script:Programs    = Get-InstalledPrograms
    $script:Runtimes    = Get-RuntimePrograms -Programs $script:Programs |
        Select-Object Name, Version, Publisher, @{n = 'Notes'; e = { Get-SoftwareNote $_.Name } }
    $script:AppPrograms = Get-AppPrograms -Programs $script:Programs |
        Select-Object Name, Version, Publisher, InstallDate, @{n = 'Notes'; e = { Get-SoftwareNote $_.Name } }
    $script:StoreApps   = Get-StoreApps
    $script:Drivers     = Get-DriverList
    $script:ConfigItems = Get-ConfigItems | ForEach-Object {
        $_ | Add-Member -NotePropertyName Selected -NotePropertyValue $false -PassThru
    }

    $GridApps.ItemsSource     = $script:AppPrograms
    $GridRuntimes.ItemsSource = $script:Runtimes
    $GridStore.ItemsSource    = $script:StoreApps
    $GridDrivers.ItemsSource  = $script:Drivers
    $GridConfigs.ItemsSource  = $script:ConfigItems

    Update-SummaryGrid
    $window.Cursor = [System.Windows.Input.Cursors]::Arrow
    Write-Log "Scan complete: $($script:AppPrograms.Count) apps, $($script:Runtimes.Count) runtimes, $($script:StoreApps.Count) Store apps, $($script:Drivers.Count) drivers."
}

# ----------------------------------------------------------------------------
# Backup actions
# ----------------------------------------------------------------------------
function Invoke-ConfigBackup {
    param([string]$DestRoot)

    $selected = $GridConfigs.ItemsSource | Where-Object { $_.Selected }
    if (-not $selected -or $selected.Count -eq 0) {
        Write-Log 'No items checked - nothing to back up.'
        return
    }

    $null = New-Item -ItemType Directory -Path $DestRoot -Force

    foreach ($item in $selected) {
        try {
            switch ($item.ActionType) {
                'CopyFile' {
                    if (Test-Path $item.Source) {
                        $dest = Join-Path $DestRoot (Split-Path $item.Source -Leaf)
                        Copy-Item -Path $item.Source -Destination $dest -Force
                        Write-Log "Copied file: $($item.Item) -> $dest"
                    } else {
                        Write-Log "Skipped $($item.Item): source not found ($($item.Source))"
                    }
                }
                'CopyFolder' {
                    if (Test-Path $item.Source) {
                        $dest = Join-Path $DestRoot (Split-Path $item.Source -Leaf)
                        Copy-Item -Path $item.Source -Destination $dest -Recurse -Force
                        Write-Log "Copied folder: $($item.Item) -> $dest"
                    } else {
                        Write-Log "Skipped $($item.Item): source not found ($($item.Source))"
                    }
                }
                'WslExport' {
                    $wslDest = Join-Path $DestRoot 'WSL'
                    $null = New-Item -ItemType Directory -Path $wslDest -Force
                    $distros = (wsl -l --quiet) 2>$null | Where-Object { $_ -and $_.Trim() -ne '' }
                    foreach ($d in $distros) {
                        $name = $d.Trim() -replace "`0", ''
                        if ($name) {
                            $tarPath = Join-Path $wslDest "$name.tar"
                            wsl --export $name $tarPath
                            Write-Log "Exported WSL distro '$name' -> $tarPath"
                        }
                    }
                    if (-not $distros) { Write-Log 'No WSL distros found to export.' }
                }
                'WifiExport' {
                    $wifiDest = Join-Path $DestRoot 'Wifi'
                    $null = New-Item -ItemType Directory -Path $wifiDest -Force
                    netsh wlan export profile key=clear folder="$wifiDest" | Out-Null
                    Write-Log "Exported Wi-Fi profiles -> $wifiDest"
                }
                'EnvVarsExport' {
                    $envDest = Join-Path $DestRoot 'EnvironmentVariables.txt'
                    [Environment]::GetEnvironmentVariables('User').GetEnumerator() |
                        Sort-Object Name |
                        ForEach-Object { "$($_.Name)=$($_.Value)" } |
                        Out-File -FilePath $envDest -Encoding utf8
                    Write-Log "Exported user environment variables -> $envDest"
                }
                'ScheduledTaskExport' {
                    $taskDest = Join-Path $DestRoot 'ScheduledTasks'
                    $null = New-Item -ItemType Directory -Path $taskDest -Force
                    $tasks = Get-NonMicrosoftScheduledTasks
                    foreach ($t in $tasks) {
                        $safeName = ($t.TaskName -replace '[\\/:*?"<>|]', '_')
                        $xmlPath = Join-Path $taskDest "$safeName.xml"
                        Export-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath | Out-File -FilePath $xmlPath -Encoding utf8
                    }
                    Write-Log "Exported $($tasks.Count) scheduled task(s) -> $taskDest"
                }
                'Manual' {
                    Write-Log "Manual action needed for $($item.Item): $($item.Explanation)"
                }
                default {
                    Write-Log "No automated action defined for $($item.Item)."
                }
            }
        } catch {
            Write-Log "ERROR backing up $($item.Item): $($_.Exception.Message)"
        }
    }
    Write-Log 'Backup pass finished.'
}

# ----------------------------------------------------------------------------
# Event handlers
# ----------------------------------------------------------------------------
$BtnRescan.Add_Click({ Invoke-Scan })

$BtnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Choose a folder to store the backup'
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $TxtBackupFolder.Text = $dlg.SelectedPath
    }
})

$BtnBackupSelected.Add_Click({
    if (-not $TxtBackupFolder.Text) {
        Write-Log 'Choose a backup folder first.'
        return
    }
    Invoke-ConfigBackup -DestRoot $TxtBackupFolder.Text
})

$BtnExportReport.Add_Click({
    $reportScript = Join-Path $PSScriptRoot 'New-SystemInventoryReport.ps1'
    $outDir = Join-Path $PSScriptRoot 'reports'
    $null = New-Item -ItemType Directory -Path $outDir -Force
    Write-Log "Generating Markdown report into $outDir ..."
    & $reportScript -OutputPath $outDir
    Write-Log 'Markdown report generated.'
})

Add-Type -AssemblyName System.Windows.Forms

Write-Log "Ready. Click 'Rescan' to scan the system."
$null = $window.ShowDialog()

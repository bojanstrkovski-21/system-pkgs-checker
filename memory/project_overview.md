---
name: project-overview
title: System-Pkgs-Checker Project Overview
date: 2026-06-22
version: 3
authors:
  - Bojan Shtrkovski
  - Claude Code
description: "What system-pkgs-checker is and what's been built so far"
metadata: 
  node_type: memory
  type: project
  originSessionId: 2a04348d-7ced-48b2-a9c0-2f73a636b3ed
---

system-pkgs-checker is a Windows system inventory tool. It scans a Windows machine for installed desktop apps, Microsoft Store apps, drivers, runtimes/frameworks, and config files/settings worth backing up before a reinstall or migration, then outputs a Markdown report and/or shows results in a WPF GUI. Repo: https://github.com/bojanstrkovski-21/system-pkgs-checker (pushed to `main`).

**Built so far:**
- [Inventory.psm1](Inventory.psm1) — shared scanning module: installed programs (registry uninstall keys, HKLM/HKCU, 32+64-bit) split into runtimes vs. apps, Store apps (`Get-AppxPackage`, elevation-aware with try/catch fallback to empty list), signed drivers, Wi-Fi/scheduled-task/browser-profile/printer/firewall-rule helpers, a shared `Test-IsElevated` helper, and `Get-ConfigItems` which returns each backup-worthy config item with an `ActionType` the GUI acts on: CopyFile, CopyFolder (now via `robocopy`, not `Copy-Item`), WslExport, WifiExport, EnvVarsExport, ScheduledTaskExport, BrowserProfilesExport, PrintersExport, FirewallRulesExport, DriverExport, Manual.
- [New-SystemInventoryReport.ps1](New-SystemInventoryReport.ps1) — generates the Markdown report, default output `reports/` folder inside the script dir (not Desktop).
- [SystemInventoryGUI.ps1](SystemInventoryGUI.ps1) — WinUtil-style native WPF GUI: tabs for Summary/Applications/Runtimes/Store Apps/Drivers/Configs to Backup, with checkboxes + a "Backup Selected" button that actually runs the action per config item into a chosen folder. Doesn't auto-scan on launch (opens instantly; user clicks "Scan"). Has a theme dropdown (9 themes in [themes/](themes/): default_light, Everforest hard/medium/soft x dark/light pulled from sainnhe/everforest's palette.md, plus `boledark` and `archboki_nvim` extracted from the user's own GitHub repos boledark_theme and archboki_nvim). Default theme on launch is `boledark`; picking a theme from the dropdown prompts Yes/No to remember it (writes `settings.json` next to the script, now tracked in git per [[project-git-state]]). UI is rounded-corners throughout (buttons, textboxes, tabs, checkboxes, dropdown, scrollbar thumbs — not the native window chrome itself), uses MesloLGS Nerd Font + Medium weight inherited from the root Window.
- All former "Manual" config items are now real automated actions: browser profile folders (`robocopy` with cache-directory exclusions — see [[feedback-wpf-gotchas]] for why this matters), printers and custom firewall rules (CSV export), and a new "Driver packages" item using DISM `Export-WindowsDriver -Online` (requires elevation, reinstall later via `pnputil /add-driver *.inf /subdirs /install`).
- [start.bat](start.bat) — double-click launcher for the GUI; must use `powershell -Command "& 'path'"` form, not `-File` (see [[feedback-wpf-gotchas]]).
- [.claude/commands/start-session.md](.claude/commands/start-session.md) and `end-session.md` — session continuity commands, also triggered by plain text "start/end session" per [[feedback-session-triggers]].

**Why:** purpose is pre-reinstall/migration backup prep — figuring out what's installed and what config would be lost in a clean Windows install, with an interactive way to actually back things up rather than just a static report.

**Decided against:** the earlier idea of a static self-contained HTML report with tabs — superseded by the WPF GUI, which supports real interactivity (checkboxes that trigger actual backup actions), not just viewing.

**How to apply:** [[feedback_explanations]] for any new known-software/config notes. [[feedback-wpf-gotchas]] for DataGrid/WPF styling quirks discovered while building the GUI, useful if extending the UI further.

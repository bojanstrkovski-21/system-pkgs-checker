---
name: project-overview
title: System-Pkgs-Checker Project Overview
date: 2026-06-22
version: 1
authors:
  - Bojan Shtrkovski
  - Claude Code
description: "What system-pkgs-checker is and what's been built so far"
metadata: 
  node_type: memory
  type: project
  originSessionId: 2a04348d-7ced-48b2-a9c0-2f73a636b3ed
---

system-pkgs-checker is a Windows system inventory tool. It scans a Windows machine for installed desktop apps, Microsoft Store apps, drivers, runtimes/frameworks, and config files/settings worth backing up before a reinstall or migration, then outputs a Markdown report.

**Built so far:** [New-SystemInventoryReport.ps1](New-SystemInventoryReport.ps1) — a single PowerShell script, no dependencies. It:
- Reads installed programs from the registry uninstall keys (HKLM/HKCU, 32+64-bit), splits runtimes/frameworks (.NET, VC++, Java, Python, Node, Docker, Git, WSL, SDKs) out from general apps.
- Lists Microsoft Store apps (`Get-AppxPackage`) and signed drivers (`Win32_PnPSignedDriver`).
- Annotates known software with a regex-matched explanation/backup note (`$KnownDescriptions` table); unrecognized software gets a blank note rather than a guessed one.
- Flags config items worth backing up: SSH keys, `.gitconfig`, PowerShell profile, Windows Terminal settings, VS Code settings, hosts file, WSL distros, mapped drives, Wi-Fi profiles, env vars, non-Microsoft scheduled tasks, browser profile folders, printers, custom firewall rules — each with a short why-it-matters note.
- Outputs one timestamped `.md` file to the Desktop by default (`-OutputPath` overridable), plus a final backup checklist.
- Works unelevated but recommends running as Administrator for complete driver/Store-app data.

**Why:** purpose is pre-reinstall/migration backup prep — figuring out what's installed and what config would be lost in a clean Windows install.

**Pending/next ask:** the user asked about wrapping this in a web UI with tabs (one tab per report section: apps, runtimes, Store apps, drivers, configs) instead of a flat Markdown file, viewed locally. Not yet implemented. Constraint already established: the browser can't do registry/WMI/driver scans itself, so PowerShell must still do the scanning — the plan was to have the script emit both the `.md` file and a self-contained static `.html` file with tabs (no server needed), then auto-open it in the default browser.

**How to apply:** [[feedback_explanations]] — if resuming the web-UI request, build the HTML as a second output alongside the existing Markdown, not a replacement, and keep the same data-gathering functions.

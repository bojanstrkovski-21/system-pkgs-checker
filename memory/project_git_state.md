---
name: project-git-state
description: Current git state of system-pkgs-checker
metadata: 
  node_type: memory
  title: Repo Pushed; .gitignore Narrowed and Settled
  date: 2026-06-22
  version: 2
  authors: 
    - Bojan Shtrkovski
    - Claude Code
  type: project
  originSessionId: 2a04348d-7ced-48b2-a9c0-2f73a636b3ed
---

Repo: https://github.com/bojanstrkovski-21/system-pkgs-checker, branch `main`. Latest pushed commit as of 2026-06-24: `92e75ac` ("Fix checkbox binding bug, add robocopy-based backups, and driver export"). Earlier commits: `1c5b07b` (initial), `082e8f6` (.gitignore narrowed), `94e2611` (memory sync).

`.gitignore` only excludes `.claude/scheduled_tasks.lock`. `reports/*.md` (generated Markdown reports) and `settings.json` (the local default-theme preference) are intentionally tracked — confirmed both are committed in the repo now. This was the user's deliberate call, not an oversight.

**Resolved:** the previously-pending `git add .` (after the `.gitignore` narrowing) was completed — `settings.json` is tracked as of commit `082e8f6`/`94e2611`. No outstanding git work pending.

**Why:** user's explicit edit to `.gitignore` — don't revert this without being asked.

**How to apply:** [[project-overview]] — when resuming git work here, respect the narrowed `.gitignore` as-is; reports and settings.json are expected to show up in `git status` after running the scripts and should be committed along with code changes, not treated as noise.

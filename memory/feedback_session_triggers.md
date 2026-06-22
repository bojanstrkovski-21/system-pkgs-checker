---
name: feedback-session-triggers
description: "User types plain text 'start session'/'end session' instead of slash commands"
metadata: 
  node_type: memory
  title: Plain-Text Session Triggers
  date: 2026-06-22
  version: 1
  authors: 
    - Bojan Shtrkovski
    - Claude Code
  type: feedback
  originSessionId: 2a04348d-7ced-48b2-a9c0-2f73a636b3ed
---

This project has `/start-session` and `/end-session` slash commands defined in `.claude/commands/`. The user prefers not to type the leading `/`. If the user's message is (or clearly amounts to) the plain text "start session" / "start-session" or "end session" / "end-session" with no other content, treat it as invoking that slash command and follow its file's steps exactly (read `.claude/commands/start-session.md` or `end-session.md` in this project for the current step list, since they may change).

**Why:** slash commands require the `/` prefix at the harness level and that can't be configured away; this is the workaround.

**How to apply:** [[project-overview]] — only applies within this project (system-pkgs-checker). Don't over-trigger on messages that merely mention "session" in passing.

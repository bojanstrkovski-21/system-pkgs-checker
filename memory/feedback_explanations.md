---
name: feedback-explanations
title: Inventory Notes Must Not Be Guessed
date: 2026-06-22
version: 1
authors:
  - Bojan Shtrkovski
  - Claude Code
description: "User wants brief explanations attached to inventory items, not guesses"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 2a04348d-7ced-48b2-a9c0-2f73a636b3ed
---

For [[project-overview]]: when listing installed software/configs, attach a brief plain-language explanation of what it is and/or why it matters for backup — but only for recognized items. Don't guess at unrecognized software; leave the note blank instead of fabricating one.

**Why:** explicit design choice made when building the inventory script — accuracy of notes matters more than completeness.

**How to apply:** carry this rule into any future additions to the known-software/config tables, and into the planned web UI version.

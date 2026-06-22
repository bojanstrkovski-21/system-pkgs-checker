---
description: Write session learnings to memory, sync the project-local copy, and end the session
---

End the current session.

1. Review this session's conversation for anything that qualifies as memory per the memory-system rules already in effect (project facts/decisions, feedback/corrections, user info, references) — exclude anything derivable from code, git history, or already covered by an existing memory file.
2. For each new or changed fact, update or create the relevant memory file under `C:\Users\User\.claude\projects\d--My-Backups-Bojan-system-pkgs-checker\memory\`, following the existing frontmatter convention (`name`, `title`, `date` created, `version` — bump by 1 on edit, `authors: [Bojan Shtrkovski, Claude Code]`, `description`, `metadata.type`). Update `MEMORY.md` index entries as needed.
3. Copy every file from `C:\Users\User\.claude\projects\d--My-Backups-Bojan-system-pkgs-checker\memory\` into the project-local `memory/` folder (inside this working directory), overwriting the old copies, so both locations are identical.
4. Confirm to the user in 2-3 sentences what was saved/updated, then state the session is ended.

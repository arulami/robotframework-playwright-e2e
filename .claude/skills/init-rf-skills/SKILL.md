---
name: init-rf-skills
description: Copy the user's `rf-*` Robot Framework skills from `~/.claude/skills/` into the current project's `.claude/skills/` so they can be committed and shared with the team. Use when bootstrapping a project with team-shared Robot Framework workflows.
disable-model-invocation: true
---

# Initialize Robot Framework Skills in Project

Copy `rf-*` skills from `~/.claude/skills/` into `<project>/.claude/skills/`, with conflict resolution.

## Workflow

### 1. Verify project context

Confirm cwd is a project root (`pyproject.toml` or `robot.toml` exists). Otherwise stop and tell the user this skill must be run from a project root.

### 2. Discover sources

```bash
ls -d ~/.claude/skills/rf-*/ 2>/dev/null
```

For each candidate directory, resolve symlinks (`readlink -f` on macOS or `realpath` if available) — entries under `~/.claude/skills/` may symlink to `~/.agents/skills/...`. Use the resolved path as the source.

If nothing is found, stop and report: *"No `rf-*` skills found in `~/.claude/skills/`. Nothing to copy."*

### 3. Validate integrity

For each candidate skill directory:
- Must contain `SKILL.md` — if missing, mark `[BROKEN: no SKILL.md]` and exclude from selection.
- `SKILL.md` must start with `---` and have `name:` + `description:` in frontmatter — if not, mark `[BROKEN: invalid frontmatter]` and exclude.

### 4. Classify each item

For every valid candidate, compare against the project target at `<project>/.claude/skills/<skill-name>/`:

- **NEW** — target does not exist
- **IDENTICAL** — target exists, content matches (`diff -rq <source> <target>` returns empty)
- **DRIFTED** — target exists, content differs

### 5. Show inventory and ask which to copy

Print a table with each item and its status, including any `[BROKEN]` entries (with reasons) for visibility. Then use `AskUserQuestion` to multi-select which to copy:

- Default-checked: `NEW` and `DRIFTED`
- Default-unchecked: `IDENTICAL` (no work needed)
- `BROKEN` items: not selectable

If everything is deselected, stop and report nothing was copied.

### 6. Ensure target directory exists

```bash
mkdir -p .claude/skills
```

### 7. Copy and resolve conflicts

For each selected item:

- **NEW** → `cp -R <source-dir> .claude/skills/`
- **DRIFTED** → per-item `AskUserQuestion`: **Overwrite / Show diff / Skip**
  - **Overwrite** → remove project copy, then `cp -R` from source
  - **Show diff** → run `git diff --no-index <project-dir> <source-dir>`, then re-prompt **Overwrite / Skip**
  - **Skip** → leave project copy untouched
- **IDENTICAL** (if user kept it selected) → skip with note "already up to date"

### 8. Print summary

```
Copied:    <N> (<list>)
Skipped:   <N> (<list>)
Identical: <N>
Broken:    <N> (<list with reasons>)
```

### 9. Print precedence reminder

> **Heads up:** your personal copies in `~/.claude/skills/` will continue to override these project copies on **your** machine (Claude Code precedence: personal > project for skills). Teammates without the personal copies will use the project versions, which is the point of committing them.

## Notes

- One-way only: never modify or delete files in `~/.claude/skills/`.
- Do not commit on the user's behalf — leave files for the user to review and stage.
- Do not touch any unrelated skills already in `.claude/skills/` — only operate on items you copy.
- This skill copies whatever is currently in the user folder. If you want a self-contained version (rule embedded in SKILL.md so it works on a fresh machine), use the same pattern as `init-robotframework-architecture` instead.

---
name: reconcile-robotframework-rules-and-skills
description: Bidirectional sync of Robot Framework rules and `rf-*` skills between the current project and user-level locations (`~/.claude/` and `~/.cursor/`). For each drifted item the user picks the winning side (project → user or user → project). Use after editing rules/skills on either side and you want both in sync.
disable-model-invocation: true
---

# Reconcile Robot Framework Rules and Skills

Bidirectional sync of Robot Framework rules and `rf-*` skills between the current project and the user's personal skill/rule locations. The user picks the winning direction for each drifted item.

- For rules: the **project** stores them as `<project>/.cursor/rules/robotframework-*.md` (or `<project>/.claude/rules/robotframework-*.md`); the **user level** stores them as the embedded `<!-- RULES_START -->` block inside `~/.cursor/skills/init-robotframework-<name>/SKILL.md` (or `~/.claude/skills/init-robotframework-<name>/SKILL.md`).
- For skills: directories `<project>/.cursor/skills/rf-*/` (or `<project>/.claude/skills/rf-*/`) ↔ `~/.cursor/skills/rf-*/` (or `~/.claude/skills/rf-*/`).

## Workflow

### 1. Verify project context

cwd must contain `pyproject.toml` or `robot.toml`. At least one of `.cursor/rules/`, `.claude/rules/`, `.cursor/skills/`, `.claude/skills/`, `~/.cursor/skills/init-robotframework-*`, `~/.claude/skills/init-robotframework-*`, `~/.cursor/skills/rf-*`, or `~/.claude/skills/rf-*` must exist. Otherwise stop and tell the user there is nothing to reconcile.

### 2. Discover candidates on both sides

```bash
# Project rules (check both locations)
ls .cursor/rules/robotframework-*.md 2>/dev/null
ls .claude/rules/robotframework-*.md 2>/dev/null

# Project skills (check both locations)
ls -d .cursor/skills/rf-*/ 2>/dev/null
ls -d .claude/skills/rf-*/ 2>/dev/null

# User installer skills (check both locations, each holds one embedded rule)
ls -d ~/.cursor/skills/init-robotframework-*/ 2>/dev/null
ls -d ~/.claude/skills/init-robotframework-*/ 2>/dev/null

# User skills (check both locations)
ls -d ~/.cursor/skills/rf-*/ 2>/dev/null
ls -d ~/.claude/skills/rf-*/ 2>/dev/null
```

For each user-level `rf-*` directory, resolve symlinks (`readlink -f` or equivalent). If the user-level entry is a symlink to e.g. `~/.agents/skills/<name>`, treat the resolved path as the user-level location. Confirm with the user before writing through a symlink.

When the same item exists under both `.cursor/` and `.claude/` on either side, prefer the `.cursor/` path as the canonical location. Deduplicate before building the candidate set.

### 3. Build the candidate set

The unified candidate set is the **union of names** seen on either side, partitioned into two groups:

- **Rules**: every `<name>` such that either `<project>/.cursor/rules/robotframework-<name>.md` (or `.claude/rules/`) exists OR `~/.cursor/skills/init-robotframework-<name>/SKILL.md` (or `~/.claude/skills/`) exists.
- **Skills**: every `<name>` such that either `<project>/.cursor/skills/rf-<name>/` (or `.claude/skills/`) exists OR `~/.cursor/skills/rf-<name>/` (or `~/.claude/skills/`) exists.

### 4. Classify each item

For each candidate, determine its state:

- **IDENTICAL** — present on both sides, content matches. No action.
- **DRIFTED** — present on both sides, content differs. User picks direction.
- **MISSING_AT_USER** — project has it, user does not. Implicit direction: project → user.
- **MISSING_AT_PROJECT** — user has it, project does not. Implicit direction: user → project.
- **BROKEN** — for rules only: a user-level `init-robotframework-<name>/SKILL.md` exists but its `<!-- RULES_START -->` / `<!-- RULES_END -->` markers are missing or unpaired. Skip — must be fixed manually.

Comparison method:
- **Rule** vs **installer block**: extract the text between `<!-- RULES_START -->` and `<!-- RULES_END -->` from the user-level `SKILL.md` (check `~/.cursor/skills/` first, then `~/.claude/skills/`), trim leading/trailing whitespace, compare against the project rule file (check `.cursor/rules/` first, then `.claude/rules/`, also trimmed).
- **Skill directory** vs **directory**: `diff -rq <project-skill> <user-skill>` — empty output = identical.

### 5. Show inventory

Print a table grouped by category. Show every state, including `[BROKEN]` for visibility (excluded from selection).

```
RULES (project ↔ installer skill)
  [DRIFTED]            robotframework-architecture
  [IDENTICAL]          robotframework-scripting
  [MISSING_AT_USER]    robotframework-newrule          (project has it, user doesn't)
  [MISSING_AT_PROJECT] robotframework-otherrule        (user has it, project doesn't)

SKILLS (project ↔ user)
  [DRIFTED]            rf-new-test
  [MISSING_AT_USER]    rf-coverage-planner
  [MISSING_AT_PROJECT] rf-something-else
```

### 6. Ask which items to sync

**Skip this step entirely** when the actionable set is a single item — i.e. exactly one `DRIFTED` and zero `MISSING_AT_USER` / `MISSING_AT_PROJECT`. With nothing to filter, step 6 is busywork; jump straight to step 7 for that one item.

Otherwise, use `AskUserQuestion` with multi-select.

- Default-checked: `DRIFTED`, `MISSING_AT_USER`, `MISSING_AT_PROJECT`
- Default-unchecked: `IDENTICAL`
- `BROKEN`: not selectable

For each `DRIFTED` option, the description **must** end with " (you'll pick the winning side next)" so the user understands this is a filter step and direction will be asked in step 7. For `MISSING_AT_USER` / `MISSING_AT_PROJECT` options, the description must state the implicit direction (e.g. "will copy project → user").

If the user deselects everything, stop and report nothing was synced.

### 7. Resolve direction per drifted item

For each selected `DRIFTED` item, ask the user with `AskUserQuestion`:

- **Use project version** — overwrite user-level with project's content (project → user)
- **Use user version** — overwrite project with user-level's content (user → project)
- **Show diff** — run `git diff --no-index <user-side> <project-side>`, then re-prompt with the same options minus **Show diff**
- **Skip** — leave both sides as they are

For `MISSING_AT_USER` and `MISSING_AT_PROJECT`, the direction is implicit — no question needed. Just confirm in the summary.

### 8. Apply updates — override pattern (no `rm -rf`)

For directory copies, never use `rm -rf`. Instead, relocate the existing target out of the way using `mv` to a stamped path under `/tmp`, then copy the source in fresh:

```bash
TS=$(date +%s)
# If <target> exists (DRIFTED), get it out of the way first:
[ -e <target> ] && mv <target> /tmp/<basename>-<role>-$TS
# Then copy the source in:
cp -R <source> <target_parent>/
```

`<role>` is `project` or `user` so the `/tmp` backup name records which side was overwritten. The `/tmp` copy is OS-cleaned and never registers as a skill since it lives outside `.claude/skills/`. Tell the user where the backup landed in case they want to recover it.

#### Rules: project → user

For each rule going **project → user** (covers `MISSING_AT_USER` rules and `DRIFTED` rules where the user picked **Use project version**):

1. **MISSING_AT_USER** — no `init-robotframework-<name>` skill exists at user level. Ask: **Scaffold new installer skill / Skip**. On Scaffold, create `~/.cursor/skills/init-robotframework-<name>/SKILL.md` using the template in the **Appendix**, embedding the project rule's full content between the `<!-- RULES_START -->` / `<!-- RULES_END -->` markers.
2. **DRIFTED, project wins** — read the user-level installer `SKILL.md`. Confirm `<!-- RULES_START -->` and `<!-- RULES_END -->` each appear exactly once (else mark `BROKEN` and skip). Use the `Edit` tool with `old_string` = the entire current block (markers included) and `new_string` = the markers wrapping a blank line + the project rule's full file content + a blank line. Preserve all other lines in the installer `SKILL.md`.

#### Rules: user → project

For each rule going **user → project** (covers `MISSING_AT_PROJECT` rules and `DRIFTED` rules where the user picked **Use user version**):

1. Extract the rule content from between the `<!-- RULES_START -->` / `<!-- RULES_END -->` markers in the user-level `SKILL.md` (check `~/.cursor/skills/` first, then `~/.claude/skills/`). Trim leading/trailing blank lines.
2. `mkdir -p .cursor/rules` if needed (use whichever rules directory the project already uses; default to `.cursor/rules/` for new projects).
3. Write the extracted content verbatim to `.cursor/rules/robotframework-<name>.md` (or `.claude/rules/` if that's the project's convention). Overwriting is safe for text files.

#### Skills: project → user

For each skill going **project → user** (`MISSING_AT_USER` or `DRIFTED, project wins`):

```bash
TS=$(date +%s)
# Use whichever user-level location exists; default to ~/.cursor/skills/
USER_SKILLS=~/.cursor/skills  # or ~/.claude/skills if that's what the user has
[ -e $USER_SKILLS/<name> ] && mv $USER_SKILLS/<name> /tmp/<name>-user-$TS
cp -R <project-skills-dir>/<name> $USER_SKILLS/
```

If the user-level entry was a symlink, write to the resolved real path instead — and only after confirming.

#### Skills: user → project

For each skill going **user → project** (`MISSING_AT_PROJECT` or `DRIFTED, user wins`):

```bash
TS=$(date +%s)
# Use whichever project-level location exists; default to .cursor/skills/
PROJECT_SKILLS=.cursor/skills  # or .claude/skills if that's the project's convention
mkdir -p $PROJECT_SKILLS
[ -e $PROJECT_SKILLS/<name> ] && mv $PROJECT_SKILLS/<name> /tmp/<name>-project-$TS
cp -R <user-skills-dir>/<name> $PROJECT_SKILLS/
```

### 9. Print summary

```
Rules:
  Project → User:    <N> (<list>)
  User → Project:    <N> (<list>)
  Scaffolded:        <N> (<list>)

Skills:
  Project → User:    <N> (<list>)
  User → Project:    <N> (<list>)

Skipped:             <N>
Identical:           <N>
Broken:              <N> (<list with reasons>)

Backups (in /tmp, OS-cleaned):
  <list of /tmp/<name>-<role>-<ts> paths created during this run>
```

### 10. Print follow-up reminder

> **Next steps:**
> - To propagate updates to other projects, run `/init-robotframework-architecture`, `/init-robotframework-scripting`, or `/init-rf-skills` in each project.
> - Skills precedence: on **your** machine, the user-level `rf-*` (in `~/.cursor/skills/` or `~/.claude/skills/`) always overrides any project-level copy of the same name. Pushing into a project via `/init-rf-skills` does **not** change this — its purpose is to give teammates and CI (machines without your personal copy) the same skill via the project version.
> - Backups in `/tmp/` are not auto-deleted by this skill. macOS clears them on reboot or after a few days; remove sooner if disk space matters.

## Notes

- This skill is bidirectional but leaves direction up to the user per drifted item — no auto-merge.
- Removal is out of scope. If an `rf-*` or `init-robotframework-*` exists on only one side and the user wants to delete instead of copy, they should do so manually.
- Always operate on a clean project working tree when possible — easier to roll back project-side changes via git.
- The `/tmp` backup pattern avoids `rm -rf` entirely. Old versions sit in `/tmp` until the OS cleans them.
- The skill checks both `.cursor/` and `.claude/` paths on both sides. When creating new items, prefer `.cursor/` for project-level and `~/.cursor/` for user-level unless the existing setup uses `.claude/`.

## Appendix — Installer skill template

Used when scaffolding a new `init-robotframework-<name>` skill for a project rule that has no installer yet. `<NAME>` and `<DESCRIPTION>` are substituted; `{{RULE_CONTENT}}` is the verbatim project rule file content.

```markdown
---
name: init-robotframework-<NAME>
description: <DESCRIPTION — ask the user for one short sentence>
---

# Initialize Robot Framework <NAME> Rule

Write the Robot Framework <NAME> rule to `.cursor/rules/robotframework-<NAME>.md` (or `.claude/rules/`) in the current project.

## Target File

`.cursor/rules/robotframework-<NAME>.md` (or `.claude/rules/robotframework-<NAME>.md` — match the project's existing convention)

## Workflow

1. Verify cwd contains `pyproject.toml` or `robot.toml`. Otherwise stop.
2. `mkdir -p .cursor/rules` (or `.claude/rules` to match existing project convention).
3. Check for existing target file:
   - Not present → write content from the `<!-- RULES_START -->` block below.
   - Present and identical → report `Already up to date`.
   - Present and different → ask **Overwrite / Show diff / Skip** (re-prompt **Overwrite / Skip** after diff).
4. Do NOT touch `CLAUDE.md`.

## Content to write

<!-- RULES_START -->
{{RULE_CONTENT}}
<!-- RULES_END -->

## Notes

- This skill is self-contained: re-run after pulling updates to refresh project copies.
```

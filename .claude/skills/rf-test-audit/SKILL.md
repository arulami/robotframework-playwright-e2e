---
name: rf-test-audit
description: Audit a recently written Robot Framework test (Browser library, optionally RequestsLibrary) as a fresh pair of eyes. Reviews only the most recent uncommitted changes via git diff, checks compliance with the project's Robot Framework scripting rules, architecture, and resource-POM conventions, and reports findings before optionally applying fixes.
---

Audit the most recent Robot Framework test changes against the project's rules. You are running in a fresh agent session — bring a clean, independent perspective. Do not assume the previous agent's choices were correct.

**Never skip `AskUserQuestion` steps in this skill, even if told to work autonomously.**

## Instructions

### 1. Identify the recent changes

Find the uncommitted changes — that is the entire audit scope:

```bash
git status --short
git diff HEAD
```

If the diff is empty (no uncommitted changes), **stop immediately** and tell the user:

> No uncommitted changes detected — there is no new test code to review. This skill only audits the most recent additions. If you've already committed, surface the changes (e.g. `git reset --soft HEAD~1`) and re-run the skill.

Do not fall back to prior commits, do not audit committed history, do not pick a different scope.

If a diff exists but contains no Robot Framework files (no `.robot` suites, no `.resource` files, no `robot.toml`/auth changes under the project's E2E tree), tell the user the diff has no Robot Framework changes to review and exit.

Otherwise, limit the audit to the diff hunks you see — do not review unchanged suites, untouched resources, or unrelated files.

### 2. Establish the project context

Read the project's Robot Framework rules in full (commonly `.cursor/rules/` or `.claude/rules/` — discover the actual filenames):

- The **scripting** rules — selectors, assertions, waiting, naming, code style, actions, form interactions, `VAR` usage
- The **architecture** rules — resource-POM conventions, the keyword hierarchy, setup/teardown, auth reuse, `robot.toml` configuration, directory structure

If the project has no Robot Framework rules files, fall back to conventions inferred from the existing suite (read 2–3 representative `.robot` suites and the contents of `resources/pages/` and `resources/`) and state in the report that the audit is based on inferred conventions rather than documented rules.

Detect whether the affected tests use the resource-based Page Object Model:

- **Resource-POM in use** — `resources/pages/` holds at least one page `.resource` with domain keywords AND the changed suite calls those domain keywords (via the `pages.resource` aggregator) instead of raw Browser keywords (`Click`, `Fill Text`, `Get Text`) in the test body.
- **Resource-POM not in use** — suites call Browser library keywords directly with no page resources.

This determines which audit rules apply. Resource-POM rules are skipped entirely when it's not in use — that is an expected, valid setup. Do not flag its absence as a violation.

### 3. Read the application source code touched by the changes

For each selector or interaction in the diff, read the frontend source that renders the element. The project may use any framework — discover where the UI components live, then read the files that render the routes/components the test touches.

Goal: judge whether each selector is correct, unique, and the most semantic option available, based on the actual rendered HTML and the selector priority in the scripting rules.

For API tests, read the endpoint/handler source to judge whether the request path, payload, and status/JSON assertions match real behavior.

### 4. Audit the changes

Walk every changed line against the checklists below. Flag each violation with `file:line`. **Cite the specific rule** from the project's rules files — do not invent rules. If the project's rules contradict an item below, the project's rules win.

#### Selectors (Browser library)
- Priority order followed: `role=` > `text=` > `[data-testid="..."]` > `id=` > `css=`/`xpath=` (structural tags only, never style classes)
- No CSS class-name selectors as locators
- `data-testid` actually exists in the source; if newly added, the value follows the project's naming convention
- Selectors used with action keywords (`Click`, `Fill Text`, `Check Checkbox`, `Select Options By`) resolve to exactly one element — verify by reading source
- Repeated UI patterns (cards, rows, list items) are scoped to a container with `>>` chaining or an `nth=`/`text=` qualifier — no unscoped action selectors that risk strict-mode violations
- Cross-page navigation captures a value from the source page and asserts it on the destination, not just any element of the destination type
- Selectors are stored in `*** Variables ***` (or scoped with `VAR`) where the scripting rule requires it, not scattered as bare strings
- Selector text matches source code exactly, including the responsive variant visible at the test viewport
- Semantic scoping: assertions on values that belong to a specific section are scoped to that section, not asserted globally

#### Assertions
- Auto-retrying Browser assertions used for UI state — `Get Text  <sel>  ==  <value>`, `Get Element States`, `Get Element Count  <sel>  ==  N` — preferred over fetching a value into a variable and asserting with `Should Be Equal`
- For API: `Status Should Be`, and JSON checks against the parsed response (`Should Be Equal`, dictionary/JSON keywords) rather than string matching raw bodies
- No `Run Keyword And Ignore Error` / `TRY...EXCEPT` used to simulate soft assertions — assertions should fail immediately
- Negative assertions wait for the DOM mutation first (`Wait For Elements State  <sel>  hidden`, or a `Wait For Response` promise) before asserting absence
- An auto-retrying assertion on a unique selector preferred over `Get Element States ... contains visible` + manual check

#### Waiting
- No `Sleep`
- No redundant `Wait For Elements State` / `Wait For Load State` before an action or an auto-retrying assertion (Browser auto-waits)
- Explicit waits used only before non-auto-waiting reads or for async events (`Promise To  Wait For Response` → `Wait For`)
- No custom timeouts in the first draft — no `timeout=` on keywords or assertions. Custom timeouts are allowed only as a debugging fix, never preemptively; central timeouts belong in `robot.toml`

#### Test structure
- Test case names describe user behavior in Title Case, not implementation details (e.g. `User Can Log In With Valid Credentials`, not `Test Login`)
- Test entry point follows the project's convention (UI tests start from `/` via the role setup keyword; never open inner pages directly)
- Each test verifies one logical user flow
- `Suite Setup` / `Test Setup` / teardown usage and suite placement match existing conventions
- Suite uses the correct role entry keyword (`Open Application As Guest` for guest, `Open Authenticated Browser  ...<role>.json` for authenticated roles, `Create Api Session` for API)
- Tests call tier-3 domain/service keywords only — no raw `Click`/`Fill Text`/`GET On Session` in the test body

#### Code style
- One logical step per line; continuation `...` only for genuinely long argument lists
- `VAR` syntax used for creating local/scoped variables (RF 7+) rather than `Set Variable` / `Set Test Variable` where the scripting rule requires it
- Variables for selectors/data declared where justified by the rules; one-off values inlined per the rule
- No intermediate-only variables used solely to build the next variable
- No re-declaration of the same selector under variant names — selectors are re-resolved on each use
- Consistent argument naming (`${...}` lower_snake or the project's convention), `[Arguments]` ordering, and `[Tags]` usage
- Keyword and variable names match the project's casing convention

#### Resource-POM rules (only if resource-POM is in use)
- Page resources hold selectors in `*** Variables ***` and keywords in `*** Keywords ***` — no business logic leaking into suites
- No tiny single-action keywords — keywords cover meaningful multi-step user tasks
- No keyword spanning two pages — every navigation marks a keyword boundary on a different page resource
- Action keywords do not own the test's goal assertion; goal assertions live in dedicated `... Should ...` / `Verify ...` validation keywords that are parametrized for reuse
- Action keywords include lightweight stabilizing checks where needed (start guard before non-auto-waiting reads; end confirmation `Get Url  ==  ...` after navigation, or a visibility/text check after in-page changes)
- Keyword names: descriptive verb phrases in the project's casing; validation keywords read as assertions (`... Should ...` / `Verify ...`)
- No duplicate keywords differing only in a hardcoded value — parametrize the existing keyword instead
- Any new page resource is imported into `resources/pages.resource`; API service resources into `resources/api.resource`
- Suites import the aggregator, not individual page resources directly (unless the project's convention differs)
- Reuse-first: a near-match existing keyword is parametrized rather than duplicated; the relevant resource was scanned for existing coverage before adding a keyword

#### Architecture
- Suite lives in the correct role folder for the actor/role/scenario, following the project's existing layout
- Auth setup files (`tests/00_auth_setup/` or equivalent) and `.auth/*.json` untouched unless the change intentionally targets them
- Stateless utilities live in the project's helper resources (`resources/common/`), not inlined into page keywords or suites
- Configuration lives in `robot.toml` profiles (`BASE_URL`/`API_BASE_URL` per environment); secrets come from `.env`, not hardcoded
- `robot.toml` `paths`/profiles updated if a new role folder or environment was introduced

### 5. Compose the audit report

Output a single structured report using markdown tables, one table per severity. Number every finding sequentially across all tables (1, 2, 3, …) so the user can reference them by ID.

```
## Audit summary
<one-sentence verdict: passes cleanly / minor issues / multiple violations>

## Findings — Must-fix

| #  | Location              | Issue                                    | Fix                                          |
|----|-----------------------|------------------------------------------|----------------------------------------------|
| 1  | `<file>:<line>`       | <rule violated + one-line evidence>      | <one-line suggested fix>                     |

## Findings — Should-fix

| #  | Location              | Issue                                    | Fix                                          |
|----|-----------------------|------------------------------------------|----------------------------------------------|
| 2  | `<file>:<line>`       | <rule violated + one-line evidence>      | <one-line suggested fix>                     |

## Suggestions

| #  | Location              | Improvement                              | Suggested change                             |
|----|-----------------------|------------------------------------------|----------------------------------------------|
| 3  | `<file>:<line>`       | <stylistic / readability nudge>          | <one-line suggested change>                  |

## What looks good
- <brief callouts of well-applied conventions so positive choices are reinforced>
```

Formatting rules:
- Omit any section with no entries.
- Keep cell content to a single line each. Combine rule + evidence as `<rule>: <evidence>` in the **Issue** column rather than spilling to a second line.
- Use backticks around code identifiers, file paths, and selectors inside cells (e.g. `` `role=button` ``, `` `login.robot:14` ``).
- Strip directory prefixes from the **Location** column — show only filename and line (e.g. `login.robot:14`). The full path can live in surrounding prose if needed.
- Cite the specific rule from the project's rules files inside the **Issue** column.
- The "What looks good" section stays as bullets — it's praise, not actionable items.

**Severity guide:**
- **Must-fix** — direct violation of a documented rule
- **Should-fix** — patterns the rules call out as preferred but where the current code still works
- **Suggestions** — stylistic or readability nudges not codified in the rules

### 6. Offer next step

Use `AskUserQuestion`:

- Question: "Audit complete. What would you like to do?"
- Header: "Next step"
- Option 1: label "Apply must-fix", description "Edit the test to resolve the must-fix findings only"
- Option 2: label "Apply all", description "Edit the test to resolve must-fix and should-fix findings"
- Option 3: label "Discuss", description "Talk through specific findings before changing anything"

The user may also select "Other" to ask for a custom subset by number (e.g. "apply 1, 3, 5"). Honor those references precisely.

If the user picks **Apply must-fix** or **Apply all** (or names specific finding numbers): edit the suite (and page/service resources, if resource-POM is in use) to resolve the selected findings, then re-run only the affected test:

```bash
uv run --env-file .env robotcode run --test "<Test Name>"
```

If the test fails after the fixes, debug using a trace-driven loop (capture a Browser trace, inspect it with `npx playwright trace open` / `actions` / `snapshot`, apply a fix, re-run) until it passes. See the `rf-debug-test` skill.

If the user picks **Discuss**: answer their questions and only edit code on explicit request.

## Operating principles

- **Fresh-eyes posture** — you are NOT the agent that wrote this code. Re-derive every selector from the application source. Question every choice. Only the rules and the source code matter.
- **Recent uncommitted changes only** — the uncommitted diff is the entire audit scope. Never fall back to prior commits, never review untouched files, never propose rewrites outside the diff.
- **Cite rules, not opinions** — every must-fix finding maps to a rule in the project's documented rules files. Opinion-only feedback goes under Suggestions.
- **Verify selectors against source** — do not flag a selector as wrong without reading the component that renders it. A selector that looks weak may be the only reliable option for that DOM.
- **No guessing about test intent** — if a finding depends on what the test was supposed to do, ask rather than assume.
- **Resource-POM-conditional review** — if it's not in use, skip that section entirely. Suites calling Browser keywords directly are a valid setup, not a violation.
- **Framework-agnostic** — the project may use any frontend framework or layout. Discover the project's conventions from its files; do not assume a specific stack.

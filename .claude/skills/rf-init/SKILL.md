---
name: rf-init
description: Initialize a Robot Framework E2E framework (Browser library for UI, RequestsLibrary for API, managed with `uv`) in a project. Adds dependencies, scaffolds the directory structure, multi-environment `robot.toml` profiles, auth setup, browser/API session resources, a `pages.resource` aggregator skeleton, sample smoke tests, and copies the Cursor rules.
---

Initialize a Robot Framework E2E framework (Browser library + RequestsLibrary, managed with `uv`) from scratch in the current project. Follow the steps below in order.

**Never skip `AskUserQuestion` steps in this skill, even if told to work autonomously.**

## Conventions to enforce

The generated framework follows this structure:

```
tests/
  __init__.robot                  # Suite-level docs (optional)
  00_auth_setup/
    auth.robot                    # Persists storageState per role — runs first
  <role>/
    smoke.robot                   # Generated sample smoke suite per role
  api/                            # Only if API tests requested
    smoke.robot

resources/
  pages.resource                  # Aggregator — imports every page/component resource + browser_setup
  api.resource                    # API aggregator (only if API tests requested)
  pages/                          # Page resources (empty — created on demand)
  components/                     # Component resources (empty — created on demand)
  api/                            # API service resources (only if API; created on demand)
  keywords/
    browser_setup.resource        # Browser lifecycle keywords (BaseTest analog)
    api_setup.resource            # Create Session + API helpers (only if API)

libraries/                        # Python helper keywords (empty — created on demand)

robot.toml                        # RobotCode config: paths, output dir, env profiles, variables
pyproject.toml                    # uv project + dependencies
.auth/                            # storageState JSON files — gitignored, regenerated each run
.env                              # Credentials/secrets — gitignored
.env.example                     # Committed template
.robot.toml                       # Personal config overrides — gitignored (optional)
```

Key conventions:
- **Browser library** (Playwright-based) for UI; **single browser** (Chromium), no Firefox/WebKit. **RequestsLibrary** for API (optional).
- **`uv`** for dependency management — `pyproject.toml` + `uv.lock`; everything runs via `uv run robotcode run`.
- **Config in `robot.toml`** (RobotCode) — the single source of truth for `paths`, `output-dir`, `python-path`, and non-secret variables. Each environment is a **profile** (`-p <env>`); `BASE_URL`/`API_BASE_URL`/`HEADLESS` live there. The IDE, CLI, and CI all read the same file.
- **Secrets** (role credentials, API token) live in `.env` (gitignored) and load via `uv run --env-file .env robotcode run`; referenced in suites as `%{VAR}`. Never put secrets in `robot.toml` (it's committed) — personal overrides go in a gitignored `.robot.toml`.
- **Auth reuse** via Browser's `Save Storage State` → `.auth/<role>.json`, restored with `New Context    storageState=...`. The `00_auth_setup` suite sorts first, so it runs before role suites in the same execution.
- **Per-role suites** under `tests/<role>/`. Authenticated roles open a context from `.auth/<role>.json` in `Suite Setup`; unauthenticated roles (guest) open a plain context.
- **Single import surface** — suites import `resources/pages.resource` (UI) and/or `resources/api.resource` (API); page/service resources are added to the aggregator as they are created.
- **Selectors as variables** and **keywords as multi-step tasks** per the architecture/scripting rules.

## 1. Gather requirements

Use `AskUserQuestion` and free-form chat to collect inputs. Ask in this order.

### 1.1 Test types

Use `AskUserQuestion`. Configure:

- **header**: `Test types`
- **question**: `What kinds of tests will this project hold? This decides whether I scaffold the RequestsLibrary API layer (resources/api, resources/api.resource, tests/api) alongside the Browser UI layer.`
- **multiSelect**: `false`
- **options**:
  1. `UI only` — `Browser library only; skip the API scaffolding`
  2. `UI + API` — `Browser library for UI plus RequestsLibrary for API`

If the user picks "Other", parse their intent. If API is not included, skip every API-specific file in later steps.

### 1.2 Environments

Use `AskUserQuestion`. Configure:

- **header**: `Environments`
- **question**: `How many test environments do you need, and what should they be called? Provide a baseURL for each. Example: local: http://localhost:3000, qa: https://qa.example.com`
- **multiSelect**: `false`
- **options**:
  1. `Just local` — `Single env, BASE_URL=http://localhost:3000`
  2. `local + qa` — `Two envs; I'll ask for the qa baseURL next`
  3. `local + qa + production` — `Three envs; I'll ask for qa and production baseURLs next`

If the user picks a preset that needs additional baseURLs (qa/production), follow up via plain chat to collect each URL. If the user picks "Other", parse their free-form list.

The first env listed becomes the default RobotCode profile (`default-profiles` in `robot.toml`).

### 1.3 Auth roles

Use `AskUserQuestion`. Configure:

- **header**: `Auth roles`
- **question**: `What auth roles do you need? Each authenticated role gets a test case in tests/00_auth_setup/auth.robot (which saves its storageState) plus a role suite that loads it. "guest" is unauthenticated — no setup needed for it.`
- **multiSelect**: `false`
- **options**:
  1. `guest only` — `Unauthenticated tests only; skip auth.robot`
  2. `guest + user` — `One unauthenticated role plus one authenticated role`
  3. `user + admin` — `Two authenticated roles, no guest`
  4. `guest + user + admin` — `One unauthenticated role plus two authenticated roles`

If the user picks "Other", parse their free-form list. If only `guest` is in the final list, skip generating `tests/00_auth_setup/auth.robot` and the authenticated `Suite Setup` wiring.

### 1.4 Login flow details (only if any authenticated roles)

Use `AskUserQuestion`. Configure:

- **header**: `Login flow`
- **question**: `How should I figure out the login flow for auth.robot? I need: link text to the login page from /, form field labels for email and password, and the URL each role lands on after login.`
- **multiSelect**: `false`
- **options**:
  1. `Explore the source code` — `I'll search the codebase for the login page, form fields, and post-login URL, then write the setup`
  2. `Generate placeholders` — `I'll use generic placeholder values with a # TODO marker; the user fills them in later`
  3. `I'll provide the details` — `User types the link text, field labels, and post-login URL via "Other"`

If the user picks **Explore the source code**: search for the login page (look in `src/main/`, `src/app/`, components matching `Login*`, or routes referenced by a "Log In"/"Sign In" link). Identify the email/password input labels and the post-login redirect target. Use those exact values when generating `auth.robot`. If the search yields nothing reliable, fall back to the `Generate placeholders` path.

If the user picks **Generate placeholders**: use placeholder values and add a single `# TODO: confirm selectors` comment above each auth test case.

If the user picks **I'll provide the details** (or types their answer in "Other"): parse their input as the (a) link text, (b) email label, (c) password label, (d) post-login path.

Do not block on this step — pick a path and continue.

### 1.5 Optional extras

Use `AskUserQuestion` to ask (separate questions, two options each — yes/no):

- **Copy Cursor rules** — *"Should I copy `robotframework-architecture.md` and `robotframework-scripting.md` into `.cursor/rules/` so future AI work follows the conventions?"* Yes/no only — do **not** ask for a source path. The canonical source is the user/project skills: `init-robotframework-architecture/SKILL.md` and `init-robotframework-scripting/SKILL.md`. The rule content is embedded between `<!-- RULES_START -->` and `<!-- RULES_END -->` markers. If those files don't exist, check `.cursor/rules/` in the current project. If neither exists, tell the user clearly and skip — don't fabricate the content.

## 2. Set up `uv` and dependencies

`uv` and Node.js are prerequisites (the Browser library uses a Playwright/Node backend). Verify with `uv --version` and `node --version`; if missing, tell the user to install them and stop.

Check if `pyproject.toml` exists in the project root.

### If `pyproject.toml` exists — add dependencies

```bash
uv add robotframework robotframework-browser robotframework-requests "robotcode[runner]"
```

Omit `robotframework-requests` if the user chose **UI only** in step 1.1. `robotcode[runner]` provides the `robotcode run` CLI that reads `robot.toml`.

### If `pyproject.toml` does not exist — create the project first

Use `AskUserQuestion` to ask for the project name if not obvious from the directory. Then:

```bash
uv init --name <PROJECT_NAME> --bare
uv add robotframework robotframework-browser robotframework-requests "robotcode[runner]"
```

(`--bare` avoids generating a sample module. Omit `robotframework-requests` for **UI only**.) `uv add` resolves the latest stable versions, creates the virtualenv, and writes `uv.lock` — do not hardcode versions.

## 3. Install the browser

The Browser library needs its Playwright browser binaries installed once:

```bash
uv run rfbrowser init chromium
```

If specifying a browser fails, fall back to installing all browsers:

```bash
uv run rfbrowser init
```

If both fail (e.g. `rfbrowser` not found), tell the user to run `uv run python -m Browser.entry init chromium` manually, then continue.

## 4. Create directory structure

```bash
mkdir -p tests/00_auth_setup            # only if authenticated roles exist
mkdir -p tests/<role>                   # one per role from step 1.3
mkdir -p tests/api                      # only if API tests (step 1.1)
mkdir -p resources/pages resources/components resources/keywords
mkdir -p resources/api                  # only if API tests
mkdir -p libraries
mkdir -p .auth                          # only if authenticated roles exist
```

## 5. Generate `robot.toml`

The RobotCode config drives the run: `paths`, `output-dir`, `python-path`, default variables, and one **profile per environment**. Generate one `[profiles.<env>.extend-variables]` block per environment from step 1.2; `default-profiles` is the first env. Include the `API_BASE_URL` lines only if API tests were requested.

```toml
# RobotCode configuration — single source of truth for IDE, CLI, and CI.
paths = ["tests"]
output-dir = "results"
python-path = ["."]
default-profiles = ["<DEFAULT_ENV>"]

[variables]
HEADLESS = "true"

[profiles.<ENV_1>.extend-variables]
BASE_URL = "<ENV_1_BASE_URL>"
API_BASE_URL = "<ENV_1_BASE_URL>/api"

[profiles.<ENV_2>.extend-variables]
BASE_URL = "<ENV_2_BASE_URL>"
API_BASE_URL = "<ENV_2_BASE_URL>/api"
```

Notes:
- **Use `extend-variables` (not `variables`) in profiles.** A profile's `[profiles.<env>.variables]` table *replaces* the root `[variables]` table when that profile is active, which drops `HEADLESS` and causes `Variable '${HEADLESS}' not found` at `New Browser`. `extend-variables` merges the profile's vars on top of the root vars instead.
- `HEADLESS` is a string here; the Browser library converts `"true"`/`"false"` to a boolean for `New Browser headless=${HEADLESS}`. Override per run with `--variable HEADLESS:False`.
- `BASE_URL`, `API_BASE_URL`, and `HEADLESS` become global variables available to every suite/resource — no `Variables` import is needed.

## 6. Generate `.env.example`

Committed template listing every secret as `%{VAR}` referenced later. One email/password pair per authenticated role; `API_TOKEN` only if API tests.

```
# Copy to .env (gitignored) and fill in. Load at runtime with:
#   uv run --env-file .env robotcode run
<ROLE>_EMAIL=
<ROLE>_PASSWORD=
API_TOKEN=
```

## 7. Generate `resources/keywords/browser_setup.resource`

The BaseTest analog — browser lifecycle keywords reused by every suite.

```robotframework
*** Settings ***
Library      Browser

*** Keywords ***
Open Application As Guest
    [Documentation]    Opens an unauthenticated context at the home page.
    New Browser    chromium    headless=${HEADLESS}
    New Context    baseURL=${BASE_URL}    viewport={'width': 1280, 'height': 720}
    Set Browser Timeout    60s
    New Page       /

Open Authenticated Browser
    [Documentation]    Opens a context restored from a saved storageState file.
    [Arguments]    ${state_file}
    New Browser    chromium    headless=${HEADLESS}
    New Context    baseURL=${BASE_URL}    storageState=${state_file}    viewport={'width': 1280, 'height': 720}
    Set Browser Timeout    60s
    New Page       /

Close Application
    [Documentation]    Tears down the browser; runs even on failure.
    Close Browser
```

## 8. Generate `tests/00_auth_setup/auth.robot`

Skip if no authenticated roles. Otherwise generate one test case per authenticated role using the login flow details from step 1.4. This suite is self-contained (page resources don't exist yet) and sorts first via the `00_` prefix.

```robotframework
*** Settings ***
Documentation    Persists authenticated storageState per role. Runs first.
Library          Browser

*** Test Cases ***
Authenticate As <Role>
    [Documentation]    # TODO: confirm selectors
    New Browser    chromium    headless=${HEADLESS}
    New Context    baseURL=${BASE_URL}
    New Page       /
    Click          role=link[name="<LOGIN_LINK_TEXT>"]
    Fill Text      role=textbox[name="<EMAIL_LABEL>"]       %{<ROLE>_EMAIL}
    Fill Text      role=textbox[name="<PASSWORD_LABEL>"]    %{<ROLE>_PASSWORD}
    Click          role=button[name="Login"]
    Get Url        *=    <POST_LOGIN_PATH>
    Save Storage State    ${EXECDIR}/.auth/<role>.json
    Close Browser
```

Generate one `Authenticate As <Role>` test per authenticated role. If the user gave only partial details, leave reasonable placeholders and keep the single `# TODO: confirm selectors` comment.

## 9. Generate `resources/pages.resource` (aggregator)

The PageManager analog — the single UI import surface. Starts with just `browser_setup`; page/component resources are appended as they are created.

```robotframework
*** Settings ***
Documentation    Single import surface for all page/component keywords.
Library     Browser
Resource    keywords/browser_setup.resource
# Add page/component resources here as they are created:
# Resource    pages/home_page.resource
# Resource    components/header.resource
```

## 10. Generate the API layer (only if API tests requested)

`resources/keywords/api_setup.resource`:

```robotframework
*** Settings ***
Library      RequestsLibrary
Library      Collections

*** Keywords ***
Create Api Session
    [Documentation]    Opens an authenticated REST session reused across the suite.
    ${headers}=    Create Dictionary    Authorization=Bearer %{API_TOKEN}
    Create Session    api    ${API_BASE_URL}    headers=${headers}
```

`resources/api.resource` (API aggregator):

```robotframework
*** Settings ***
Documentation    Single import surface for all API service keywords.
Library     RequestsLibrary
Resource    keywords/api_setup.resource
# Add service resources here as they are created:
# Resource    api/users_api.resource
```

## 11. Generate sample smoke suites

One `smoke.robot` per role. Smoke suites verify the framework is wired up; they should pass once `.env` is filled in.

**Guest (unauthenticated) — `tests/guest/smoke.robot`:**

```robotframework
*** Settings ***
Resource          ../../resources/pages.resource
Suite Setup       Open Application As Guest
Suite Teardown    Close Application
Test Tags         smoke    guest

*** Test Cases ***
Home Page Loads
    Get Url    *=    /
```

**Authenticated role — `tests/<role>/smoke.robot`:**

```robotframework
*** Settings ***
Resource          ../../resources/pages.resource
Suite Setup       Open Authenticated Browser    ${EXECDIR}/.auth/<role>.json
Suite Teardown    Close Application
Test Tags         smoke    <role>

*** Test Cases ***
Authenticated Session Is Active
    [Documentation]    # TODO: replace with a real authenticated-only assertion
    Get Url    *=    /
```

**API (only if requested) — `tests/api/smoke.robot`:**

```robotframework
*** Settings ***
Resource          ../../resources/api.resource
Suite Setup       Create Api Session
Suite Teardown    Delete All Sessions
Test Tags         smoke    api

*** Test Cases ***
Api Is Reachable
    [Documentation]    # TODO: replace with a real endpoint check
    ${response}=    GET On Session    api    /    expected_status=any
    Should Be True    ${response.status_code} < 500
```

## 12. Generate `tests/__init__.robot`

Optional suite-level documentation for the top-level `tests/` suite. Execution order is controlled by directory names (`00_auth_setup` sorts first), and `paths`/`output-dir`/`python-path` come from `robot.toml`, so no separate suite-definition file is needed.

```robotframework
*** Settings ***
Documentation    E2E suite. Run with: uv run --env-file .env robotcode run
```

## 13. Update `.gitignore`

Append (create the file if missing):

```
# Robot Framework / Browser output
results/
log.html
report.html
output.xml

# Auth storage state (regenerated each run)
.auth/

# Secrets (keep .env.example committed)
.env

# RobotCode personal config overrides
.robot.toml

# uv / Python
.venv/
__pycache__/
*.pyc
```

## 14. Copy Cursor rules (only if user opted in)

If the user opted in during step 1.5, copy the Robot Framework rule files into the project's `.cursor/rules/` directory.

Check for existing rules at these locations in order:
1. `~/.cursor/skills/init-robotframework-architecture/SKILL.md` and `~/.cursor/skills/init-robotframework-scripting/SKILL.md` — extract content between `<!-- RULES_START -->` and `<!-- RULES_END -->` markers
2. `~/.claude/skills/init-robotframework-architecture/SKILL.md` and `~/.claude/skills/init-robotframework-scripting/SKILL.md` — same extraction
3. `.claude/skills/init-robotframework-architecture/SKILL.md` and `.claude/skills/init-robotframework-scripting/SKILL.md` in the current project — same extraction

If found, write the extracted content to `.cursor/rules/robotframework-architecture.md` and `.cursor/rules/robotframework-scripting.md`.

If neither source exists, check if those files already exist in `.cursor/rules/`. If they do, report `Already present` and skip. If nothing is found anywhere, tell the user clearly and skip — don't fabricate the content.

If a target file already exists in the new project, ask the user **Overwrite / Skip** before overwriting.

## 15. Final summary (last manual step)

Skill ends here. Don't pause for confirmation, don't verify the files, don't run the smoke suites.

Print the `.env` block the user must create (gitignored), rendered with their real role names, plus the run commands. Example for envs `local` + `qa`, roles `user` + `admin`, with API enabled:

> **Framework ready** — last step, create `.env` in the project root (copy from `.env.example`) and fill it in:
>
> ```
> USER_EMAIL=
> USER_PASSWORD=
> ADMIN_EMAIL=
> ADMIN_PASSWORD=
> API_TOKEN=
> ```
>
> Run tests (paths, output dir, and env profiles all come from `robot.toml`):
> ```bash
> # Default profile (local)
> uv run --env-file .env robotcode run
>
> # Specific environment profile
> uv run --env-file .env robotcode -p qa run
>
> # Headed run of one suite
> uv run --env-file .env robotcode run --variable HEADLESS:False tests/guest
>
> # By tag
> uv run --env-file .env robotcode run -i smoke
> ```

Render the block concretely with the user's real role names. Omit `API_TOKEN` and the API references if the user chose **UI only**.

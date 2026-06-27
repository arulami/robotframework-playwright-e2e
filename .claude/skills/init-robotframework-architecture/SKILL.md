---
name: init-robotframework-architecture
description: Add the Robot Framework + Browser library architecture rule to a project's `.claude/rules/` folder. Installs page-resource (Page Object) conventions, an aggregator resource, Suite/Test Setup fixtures, auth reuse with Save Storage State, API testing with RequestsLibrary, directory structure, config best practices, and anti-patterns. Use when adding Robot Framework Browser/RequestsLibrary tests to a new project or refreshing the architecture rule in an existing one.
disable-model-invocation: true
---

# Initialize Robot Framework Browser Architecture Rule

Write the Robot Framework Browser architecture rule to `.claude/rules/robotframework-architecture.md` in the current project. The rule auto-loads when Claude touches files matching `tests/**`, `resources/**`, `libraries/**`, `*.robot`, `*.resource`, or `robot.toml`.

## Target File

`.claude/rules/robotframework-architecture.md`

## Workflow

1. **Verify project context** — cwd should be a Robot Framework project managed with `uv`. Look for `pyproject.toml`/`uv.lock` (listing `robotframework`, `robotframework-browser`, and `robotframework-requests`) or existing `*.robot`/`*.resource` files. Otherwise stop and tell the user.
2. **Ensure `.claude/rules/` exists** — `mkdir -p .claude/rules`.
3. **Check for existing file**:
   - **Not present** → write the content from the `<!-- RULES_START -->` block below, then report `Created .claude/rules/robotframework-browser-architecture.md`.
   - **Present and identical** → report `Already up to date` and exit.
   - **Present and different** → use `AskUserQuestion` with options: **Overwrite / Show diff / Skip**.
     - **Overwrite** → write content, report `Updated .claude/rules/robotframework-browser-architecture.md`.
     - **Show diff** → run `git diff --no-index .claude/rules/robotframework-browser-architecture.md <temp-file-with-new-content>`, then re-prompt **Overwrite / Skip**.
     - **Skip** → leave existing file untouched, report `Skipped — kept existing file`.
4. **Do NOT** touch `CLAUDE.md`. Rules in `.claude/rules/*.md` auto-load via path frontmatter; explicit `@` imports are redundant.

## Content to write

Everything between `<!-- RULES_START -->` and `<!-- RULES_END -->` (exclusive of the markers) is the verbatim file content, including the rule's own frontmatter.

<!-- RULES_START -->

---
description: Robot Framework Browser + RequestsLibrary page/API resources, aggregator resource, Suite/Test setup, auth reuse, and test organization patterns
paths: [tests/**,resources/**,libraries/**,**/*.robot,**/*.resource,robot.toml]
---

# Robot Framework Browser Architecture

Use the **Browser** library (Playwright-based, `robotframework-browser`) for UI — never mix it with SeleniumLibrary in the same suite. Use **RequestsLibrary** (`robotframework-requests`) for API tests and for fast test-data setup/teardown.

Manage dependencies with **`uv`**. Add libraries and initialize the Browser browsers once:

```bash
uv add robotframework robotframework-browser robotframework-requests "robotcode[runner]"
uv run rfbrowser init
```

Configure the project with **`robot.toml`** (RobotCode) and run suites with `uv run robotcode run`, so the IDE, CLI, and CI all share one config (see Configuration Best Practices). Secrets stay in a gitignored `.env`, loaded via `uv run --env-file .env robotcode run`.

## When to Use What

| Pattern | When | Location |
|---------|------|----------|
| **Page Resource** (Page Object) | A page or major component with multi-step user flows | `resources/pages/` |
| **API Service Resource** | An API resource/domain with request + assertion keywords | `resources/api/` |
| **Aggregator Resource** | Single `.resource` that imports every page resource — the only thing a UI suite imports | `resources/pages.resource` |
| **Setup/Teardown Keywords** (fixtures) | Browser lifecycle, auth, DB, API — anything needing setup/teardown | `resources/keywords/` |
| **Python Helper Library** | Stateless logic that doesn't read well in Robot syntax | `libraries/` |

## Keyword Hierarchy

Keep a strict tier hierarchy — each tier hides the complexity of the tier below:

- **Tier 4 — Test cases** (`*.robot`): read as plain-language user scenarios.
- **Tier 3 — Domain keywords** (`resources/pages/*.resource`, `resources/api/*.resource`): multi-step user tasks or API service calls ("Log In With Credentials", "Create User Via Api").
- **Tier 2 — Setup/helper keywords** (`resources/keywords/*.resource`, `libraries/*.py`).
- **Tier 1 — Atomic library keywords** (`Browser`, `RequestsLibrary`): `Click`, `Fill Text`, `Get Text`, `GET On Session`, `POST On Session`, etc.

Tests live at tier 4 and call tier 3. They never call tier 1 (`Click`, `Fill Text`, `GET On Session`) directly.

## Page Resource Conventions

- One `.resource` file per page or major component
- File name: snake_case (`login_page.resource`, `course_detail_page.resource`)
- `*** Settings ***` imports `Library    Browser` and any shared resources
- **Selectors as variables** — define every selector in the page resource's `*** Variables ***` section in `SCREAMING_SNAKE_CASE`. Selectors are never hardcoded inline in keywords (that is the RF anti-pattern). Prefer Browser's readable selector strategies (`text=`, `id=`, `css=`, `xpath=`, `>>` chaining, `:has-text()`)
- **No tiny keywords** — a keyword covers a meaningful user task with multiple steps; never a single `Click` or `Fill Text`. Split anything over ~25 lines into smaller domain keywords
- **`[Arguments]` for variation** — parametrize keywords; never write two keywords differing only in a hardcoded value
- **`[Documentation]` on every keyword** — one line describing the user task
- **Strict page boundaries** — a keyword only interacts with its own page; navigation marks the end of one keyword and the start of another on the next page
- **Validation at the start** — Browser action keywords (`Click`, `Fill Text`) auto-wait for actionability, which is the start guard. Before reading state with non-asserting getters, gate with `Wait For Elements State    ${SELECTOR}    visible`
- **Validation at the end** — when the last step is an action, add a stabilizing confirmation. For navigation use `Get Url    *=    /dashboard`. For in-page changes use `Get Element States    ${SELECTOR}    *=    visible` or `Get Text    ${SELECTOR}    ==    ...`. This is a stabilizing check, not the test's goal assertion
- **Action vs validation keywords** — action keywords may include lightweight stabilizing assertions; the test's **goal** assertions live in dedicated `... Should ...` / `Verify ...` keywords, parametrized for reuse
- **No `Sleep`** — always use `Wait For Elements State`, `Wait For Load State`, or an asserting `Get*` keyword (Browser `Get*` keywords auto-retry while an assertion operator like `==` or `*=` is supplied)
- **Naming** — Title Case, descriptive verb phrases, no abbreviations or acronyms
- **Reuse first** — before adding a new keyword, scan the relevant resource. Reuse if a keyword covers the flow; parametrize an existing one if it nearly does

```robotframework
# resources/pages/login_page.resource
*** Settings ***
Library     Browser
Resource    ../keywords/browser_setup.resource

*** Variables ***
${LOGIN_EMAIL_INPUT}        input[name="email"]
${LOGIN_PASSWORD_INPUT}     input[name="password"]
${LOGIN_SUBMIT_BUTTON}      button:has-text("Login")
${LOGIN_ERROR_ALERT}        role=alert

*** Keywords ***
Log In With Credentials
    [Documentation]    Submits the login form and lands on the dashboard.
    [Arguments]    ${email}    ${password}
    Fill Text    ${LOGIN_EMAIL_INPUT}       ${email}
    Fill Text    ${LOGIN_PASSWORD_INPUT}    ${password}
    Click        ${LOGIN_SUBMIT_BUTTON}
    Get Url      *=    /dashboard

Login Error Message Should Be
    [Documentation]    Goal assertion — parametrized for reuse.
    [Arguments]    ${message}
    Get Text    ${LOGIN_ERROR_ALERT}    ==    ${message}
```

Test body reads as action → action → validation:

```robotframework
*** Test Cases ***
User Sees Error For Invalid Password
    Open Login
    Log In With Credentials       user@example.com    wrong-password
    Login Error Message Should Be    Invalid email or password
```

### Component-Level Page Resources

For widgets reused across pages (header, cart drawer, modals), create a separate resource file. Components follow the same rules as pages.

```robotframework
# resources/components/header.resource
*** Settings ***
Library    Browser

*** Variables ***
${HEADER_LOGIN_LINK}    role=link >> text=Log In

*** Keywords ***
Open Login
    [Documentation]    Clicks the header Log In link and lands on the login page.
    Click      ${HEADER_LOGIN_LINK}
    Get Url    *=    /login
```

## The Aggregator Resource (single import surface)

Robot Framework has no object construction, so the "single entry point" is **one aggregator resource** that imports every page and component resource. A suite imports only this file and gains all page keywords — the analog of a PageManager.

```robotframework
# resources/pages.resource
*** Settings ***
Documentation    Single import surface for all page/component keywords.
Library     Browser
Resource    pages/home_page.resource
Resource    pages/login_page.resource
Resource    pages/dashboard_page.resource
Resource    components/header.resource
```

Usage in a suite:

```robotframework
*** Settings ***
Resource    ../../resources/pages.resource

*** Test Cases ***
User Can Log In
    Open Login
    Log In With Credentials    user@example.com    Password123!
```

When adding a new page resource:
1. Create `resources/pages/<page_name>.resource`
2. Add one `Resource    pages/<page_name>.resource` line to `resources/pages.resource`
3. If two resources define a keyword with the same name, disambiguate at the call site with the resource-file prefix (`login_page.Log In With Credentials`). Prefer unique, page-scoped keyword names to avoid this

## Auth Reuse with Save Storage State

Authenticate once, persist cookies + localStorage to JSON, then load it into new contexts to skip login. `Save Storage State` takes an optional path and returns the saved path; `New Context    storageState=<file>` restores it.

```robotframework
# tests/00_auth_setup/auth.robot — runs first (numeric prefix orders execution)
*** Settings ***
Library     Browser
Resource    ../../resources/pages.resource

*** Variables ***
${STUDENT_STATE}    ${OUTPUT_DIR}/student.json
${ADMIN_STATE}      ${OUTPUT_DIR}/admin.json

*** Test Cases ***
Persist Student Session
    New Browser    chromium    headless=${HEADLESS}
    New Context    baseURL=${BASE_URL}
    New Page       /
    Open Login
    Log In With Credentials    %{STUDENT_EMAIL}    %{STUDENT_PASSWORD}
    Save Storage State    ${STUDENT_STATE}
    Close Browser

Persist Admin Session
    New Browser    chromium    headless=${HEADLESS}
    New Context    baseURL=${BASE_URL}
    New Page       /
    Open Login
    Log In With Credentials    %{ADMIN_EMAIL}    %{ADMIN_PASSWORD}
    Save Storage State    ${ADMIN_STATE}
    Close Browser
```

Auth setup intentionally bypasses page-level goal assertions — it only establishes and saves session state. Authenticated suites then open a pre-authenticated context in their Suite Setup:

```robotframework
# resources/keywords/browser_setup.resource
*** Settings ***
Library    Browser

*** Keywords ***
Open Authenticated Browser
    [Documentation]    Opens a context restored from a saved storage state file.
    [Arguments]    ${state_file}
    New Browser    chromium    headless=${HEADLESS}
    New Context    baseURL=${BASE_URL}    storageState=${state_file}
    New Page       /

Open Application As Guest
    [Documentation]    Opens an unauthenticated context.
    New Browser    chromium    headless=${HEADLESS}
    New Context    baseURL=${BASE_URL}
    New Page       /
```

```robotframework
# tests/student/dashboard.robot
*** Settings ***
Resource       ../../resources/pages.resource
Suite Setup    Open Authenticated Browser    ${OUTPUT_DIR}/student.json
Suite Teardown    Close Browser
```

## API Testing with RequestsLibrary

Use **RequestsLibrary** for HTTP/API tests and for seeding data. The same tiering applies: tests call tier-3 **service keywords**, never raw `GET On Session` / `POST On Session` in the test body.

- **One service resource per API resource/domain** — `resources/api/users_api.resource`, `orders_api.resource`
- **Create the session once** in Suite Setup with `Create Session    <alias>    ${API_BASE_URL}`, attaching auth headers there
- **Service keywords wrap a request + status check**, parametrized with `[Arguments]`, returning the parsed body so callers stay readable
- **Assert status explicitly** with `Status Should Be` — `*On Session` keywords already raise on non-2xx unless you pass `expected_status`
- **Goal assertions live in `... Should ...` keywords**, same as UI; service keywords stay reusable
- **Build request bodies with `Create Dictionary`** (from `Collections`); never hardcode duplicated payloads

```robotframework
# resources/api/users_api.resource
*** Settings ***
Library    RequestsLibrary
Library    Collections

*** Keywords ***
Create User Via Api
    [Documentation]    Creates a user and returns the response JSON.
    [Arguments]    ${name}    ${email}
    ${payload}=     Create Dictionary    name=${name}    email=${email}
    ${response}=    POST On Session    api    /users    json=${payload}
    Status Should Be    201    ${response}
    RETURN    ${response.json()}

Get User Via Api
    [Documentation]    Fetches a user by id and returns the response JSON.
    [Arguments]    ${user_id}
    ${response}=    GET On Session    api    /users/${user_id}
    Status Should Be    200    ${response}
    RETURN    ${response.json()}
```

Session setup keyword (reused across the suite):

```robotframework
# resources/keywords/api_setup.resource
*** Settings ***
Library    RequestsLibrary
Library    Collections

*** Keywords ***
Create Api Session
    [Documentation]    Opens an authenticated REST session reused across the suite.
    ${headers}=    Create Dictionary    Authorization=Bearer %{API_TOKEN}
    Create Session    api    ${API_BASE_URL}    headers=${headers}
```

Mirror the page aggregator with an API aggregator (`resources/api.resource`) that imports every service resource, so an API suite imports one file:

```robotframework
# resources/api.resource
*** Settings ***
Documentation    Single import surface for all API service keywords.
Library     RequestsLibrary
Resource    keywords/api_setup.resource
Resource    api/users_api.resource
Resource    api/orders_api.resource
```

Pure API suite:

```robotframework
# tests/api/users.robot
*** Settings ***
Resource          ../../resources/api.resource
Suite Setup       Create Api Session
Suite Teardown    Delete All Sessions
Test Tags         api

*** Test Cases ***
New User Is Persisted
    ${user}=       Create User Via Api    Ada Lovelace    ada@example.com
    ${fetched}=    Get User Via Api    ${user}[id]
    Should Be Equal    ${fetched}[email]    ada@example.com
```

### Hybrid UI + API

Seed preconditions and clean up through the API to keep UI tests fast and focused — set up state with service keywords, then exercise only the behavior under test through the UI.

```robotframework
# tests/student/dashboard.robot
*** Settings ***
Resource       ../../resources/pages.resource
Resource       ../../resources/api.resource
Suite Setup    Create Api Session

*** Test Cases ***
User Sees Newly Created Course On Dashboard
    ${course}=    Create Course Via Api    Intro To Robot
    Open Authenticated Browser    ${OUTPUT_DIR}/student.json
    Open Dashboard
    Dashboard Should List Course    ${course}[title]
    [Teardown]    Delete Course Via Api    ${course}[id]
```

## Directory Structure

`tests/` holds only suite files (`*.robot`) and suite init files (`__init__.robot`) — everything the runner executes. All reusable code lives in `resources/` and `libraries/`.

```
tests/
  __init__.robot              # Root suite setup/teardown (optional)
  00_auth_setup/
    auth.robot                # Persists storage state, runs first
  student/                    # Authenticated student suites
    login.robot
    courses.robot
    dashboard.robot
  admin/                      # Authenticated admin suites
    courses.robot
    users.robot
  guest/                      # Unauthenticated suites
    catalog.robot
    blog.robot
  api/                        # Pure API suites (RequestsLibrary)
    users.robot
    orders.robot

resources/
  pages.resource              # UI aggregator — imports every page/component resource
  api.resource                # API aggregator — imports every service resource
  pages/
    home_page.resource
    login_page.resource
    dashboard_page.resource
    course_detail_page.resource
  components/
    header.resource
  api/
    users_api.resource        # Service keywords (request + assertion) per domain
    orders_api.resource
  keywords/
    browser_setup.resource    # New Browser/Context/Page + auth keywords
    api_setup.resource        # Create Session + shared API helpers
  variables/
    test_data.py              # Data variable files (optional) — env config lives in robot.toml

libraries/
  data_factory.py             # Python helper keywords / data factories

robot.toml                    # RobotCode config: paths, output-dir, python-path, env profiles, variables
pyproject.toml                # uv project + dependencies
```

`robot.toml` sets `python-path = ["."]` so imports stay portable (`Resource    resources/pages.resource`) instead of fragile `../../` paths.

## Configuration Best Practices

Centralize project config in **`robot.toml`** (read by the IDE, `robotcode run`, and CI). Put `paths`, `output-dir`, `python-path`, and non-secret variables here, with one **profile per environment**. Manage the browser lifecycle in Suite Setup/Teardown and rely on Browser's built-in failure capture.

```toml
# robot.toml
paths = ["tests"]
output-dir = "results"
python-path = ["."]
default-profiles = ["local"]

[variables]
HEADLESS = "true"

[profiles.local.extend-variables]
BASE_URL = "http://localhost:3000"
API_BASE_URL = "http://localhost:3000/api"

[profiles.qa.extend-variables]
BASE_URL = "https://qa.example.com"
API_BASE_URL = "https://qa.example.com/api"
```

> Use `extend-variables` (not `variables`) in profiles: a profile's `variables` table *replaces* the root `[variables]` when active, dropping `HEADLESS` and causing `Variable '${HEADLESS}' not found`. `extend-variables` merges onto the root vars.

```robotframework
# A typical suite — config variables (BASE_URL, HEADLESS) come from robot.toml, globally available
*** Settings ***
Resource          ../../resources/pages.resource
Suite Setup       Open Application As Guest
Suite Teardown    Close Browser
```

- **Secrets are never in `robot.toml`** (it's committed) — keep credentials/tokens in a gitignored `.env` (referenced as `%{VAR}`) and run with `uv run --env-file .env robotcode run`. Personal overrides go in a gitignored `.robot.toml`.
- Browser's default `run_on_failure` action is **Take Screenshot** — failures auto-capture a screenshot.
- Enable tracing for debugging with `Start Tracing` / `Stop Tracing` (Browser writes a Playwright trace zip you can open with `rfbrowser show-trace`).
- Set default timeouts via `Set Browser Timeout` / `Set Retry Assertions For` rather than hardcoding waits.
- Use named variables for timeouts and expected values — no magic numbers.

### Running and CI

```bash
# Default profile (local)
uv run --env-file .env robotcode run
# Specific environment profile
uv run --env-file .env robotcode -p qa run
# Headed run of one suite, or filter by tag
uv run --env-file .env robotcode run --variable HEADLESS:False tests/guest
uv run --env-file .env robotcode run -i smoke
```

In CI, select the profile with `-p <env>` and keep `output-dir`/`paths` in `robot.toml`. Start any dev server as a separate CI step (Robot has no built-in webServer); gate the suite on the server being reachable.

## Suite / Test Setup Hooks

When every test in a suite shares the same setup (e.g., starting at the home page), use `Suite Setup` for once-per-suite work and `Test Setup` for per-test work. Use `Test Teardown` / `Suite Teardown` for cleanup that must run even on failure.

```robotframework
*** Settings ***
Resource          ../../resources/pages.resource
Suite Setup       Open Application As Guest
Suite Teardown    Close Browser
Test Tags         guest    smoke

*** Test Cases ***
Home Page Displays Key Sections
    Home Hero Should Be Visible

User Can Navigate To Blog
    Open Blog
    Blog Articles List Should Be Visible
```

For per-test isolation when tests mutate state, open a fresh context per test instead of per suite:

```robotframework
Test Setup       New Context    baseURL=${BASE_URL}
Test Teardown    Close Context
```

## Anti-Patterns

- **Hardcoded selectors inline in keywords** — define every selector in the page resource's `*** Variables ***` section
- **Mixing Browser and SeleniumLibrary** in one suite — pick one; their keywords are not interchangeable
- **Single-action keywords** (`Click Login Button`, `Fill Email`) — fold them into a multi-step domain keyword
- **God keywords** doing too much — split anything over ~25 lines
- **Keywords spanning two pages** — every navigation marks a keyword boundary on a different page resource
- **Action keywords owning goal assertions** — the test's goal lives in a separate `... Should ...` / `Verify ...` keyword
- **Duplicate keywords differing only in a hardcoded value** — parametrize with `[Arguments]` instead
- **`Sleep` for synchronization** — use `Wait For Elements State`, `Wait For Load State`, or asserting `Get*` keywords
- **Magic numbers** for timeouts/expected values — use named variables
- **Untagged tests** — tag suites and tests for selective execution
- **Tests calling tier-1 library keywords directly** — tests call tier-3 domain/service keywords only (`Click`, `Fill Text`, `GET On Session`, `POST On Session` never appear in a test body)
- **Raw requests in tests** — wrap every call in a service keyword that asserts status and returns the parsed body
- **Re-creating the session per request** — `Create Session` once in Suite Setup; reuse the alias, `Delete All Sessions` in teardown
- **Driving slow UI for data setup** — seed preconditions and clean up via API service keywords; reserve the UI for the behavior under test
- **Shared mutable state** between tests — each test must be independent; reset context per test when needed
- **Absolute `${CURDIR}`/`../../` import chains** — rely on `python-path = ["."]` in `robot.toml` with the `resources/` layout
- **Skipping teardown** — Suite/Test Teardown must close the browser/context even on failure

<!-- RULES_END -->

## Notes

- The `@` symbol at the start of a line is treated as a file import by Claude Code — escape with `\@` in prose if it ever appears (none in current content).
- This skill is **self-contained**: the rule lives inside `SKILL.md`, so it works on any machine, even one without other Robot Framework skills installed.
- To update the rule across projects, update this `SKILL.md` once, then re-run the skill in each project.

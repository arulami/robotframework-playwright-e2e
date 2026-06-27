---
name: rf-refactor-into-pom
description: Refactor existing Robot Framework tests (Browser library) into a resource-based Page Object Model with page/component `.resource` files aggregated by `resources/pages.resource`. Detects an existing resource-POM and mimics its style; bootstraps the POM infrastructure when none exists. Enforces project-specific POM conventions — selectors in `*** Variables ***`, no tiny keywords, strict page boundaries, entry/exit validation, dedicated validation keywords, and reuse-first keyword design.
---

Refactor existing Robot Framework tests (Browser library) to use the project's resource-based Page Object Model. Test cases stay structurally identical — only their bodies change to call domain keywords from page resources.

**Never skip `AskUserQuestion` steps in this skill, even if told to work autonomously.**

## Instructions

### 1. Ask which tests to refactor

Use the `AskUserQuestion` tool:

- Question: "Which tests should I refactor?"
- Header: "Refactor scope"
- Option 1: label "All tests", description "Refactor every suite under `tests/`"
- Option 2: label "Specific test", description "I'll name the suite or test case to refactor"

If the user picks "Specific test", ask for the suite file or test case name to target. Confirm the resolved scope before proceeding.

### 2. Inventory the existing resource-POM

Read the project's page resources and setup infrastructure. Discover the layout from `robot.toml` (`paths`, `python-path`) and the `tests/` + `resources/` trees:

- `resources/pages/` — every page/component `.resource` and its public keywords
- `resources/pages.resource` (and `resources/api.resource`) — the aggregator(s) suites import
- `resources/common/` (and `resources/config/`) — setup keywords, helper keywords, browser/api session management you may reuse but never inline into a page resource

For each existing page resource capture:
- File name and the keywords it exposes (so you reuse instead of duplicating)
- Style cues (naming, argument shape, `*** Variables ***` selector style, assertion style)

If no resource-POM exists yet, you'll bootstrap it in step 5.

### 3. Analyze the tests in scope

For each suite in scope:
- Read it end-to-end
- For each page or component the test touches, read the corresponding source so you understand the real DOM and can pick reliable selectors per the project's scripting rules
- Group the test's steps by **the page they operate on** — every navigation marks a keyword boundary on a different page resource
- For each step group decide:
  - **Reuse** — an existing keyword already covers it
  - **Parametrize** — an existing keyword nearly covers it; widen its arguments instead of duplicating
  - **Add** — the page resource exists but no keyword covers this flow
  - **New page** — no resource exists yet for that page

Write down the mapping (test step group → page keyword) before touching code. This avoids creating tiny one-off keywords.

### 4. POM rules — design every keyword against these

These rules are non-negotiable. Apply them on every new or edited page resource.

#### File structure

- One `.resource` per page or major component, under `resources/pages/`
- File name: snake_case matching the page (`login_page.resource`, `course_detail_page.resource`)
- Selectors live in `*** Variables ***`; keywords live in `*** Keywords ***` — no business logic in suites
- The resource imports the Browser library (or relies on the aggregator/common import per project convention)

```robotframework
*** Settings ***
Library    Browser

*** Variables ***
${LOGIN_EMAIL}       role=textbox[name="Email"]
${LOGIN_PASSWORD}    label=Password
${LOGIN_SUBMIT}      role=button[name="Login"]

*** Keywords ***
Log In With Credentials
    [Arguments]    ${email}    ${password}
    Fill Text     ${LOGIN_EMAIL}       ${email}
    Fill Text     ${LOGIN_PASSWORD}    ${password}
    Click         ${LOGIN_SUBMIT}
    Get Url       *=    /dashboard
```

```robotframework
# BAD — bare selectors scattered in the suite, raw Browser keywords in the test body
*** Test Cases ***
User Can Log In
    Fill Text    role=textbox[name="Email"]    user@example.com
    Click        role=button[name="Login"]
```

#### Selectors in `*** Variables ***`

Declare selectors as variables in the page resource's `*** Variables ***` section (or scope them with `VAR` inside a keyword when local). Follow the selector priority from the scripting rules (`role=` > `text=` > `[data-testid="..."]` > `id=` > `css=`/`xpath=` for structural scoping). Reusing the same selector across keywords is fine — selectors re-resolve on each use.

#### Keyword size & granularity

A keyword represents a meaningful user task with multiple steps. Single-action keywords (one click, one fill) are an anti-pattern — fold them into the surrounding flow.

```robotframework
# BAD — tiny keyword
Click Login Button
    Click    ${LOGIN_SUBMIT}

# GOOD — meaningful flow
Log In With Credentials
    [Arguments]    ${email}    ${password}
    Fill Text    ${LOGIN_EMAIL}       ${email}
    Fill Text    ${LOGIN_PASSWORD}    ${password}
    Click        ${LOGIN_SUBMIT}
    Get Url      *=    /dashboard
```

#### Strict page boundaries

A keyword only interacts with its own page. When an action triggers navigation, the keyword ends at the navigation assertion; the **next** page's keyword takes over. Never combine steps from two pages in one keyword.

```robotframework
# BAD — one keyword spans two pages
Log In And Open First Course
    [Arguments]    ${email}    ${password}
    Fill Text    ${LOGIN_EMAIL}    ${email}
    ...
    Click    role=link[name="Courses"]          # dashboard now
    Click    role=article >> nth=0 >> role=link

# GOOD — split across page resources, composed in the test
Log In With Credentials    ${email}    ${password}    # login_page.resource
Open First Course                                       # dashboard_page.resource
```

#### Validation at the start

If the keyword's first Browser call auto-waits (`Click`, `Fill Text`, `Check Checkbox`, an auto-retrying `Get*` assertion, etc.), the auto-wait is the start guard — no extra code needed. Otherwise add an explicit `Wait For Elements State` or an auto-retrying assertion before any non-auto-waiting read (`Get Text` into a variable, `Get Element Count` into a variable, `Get Elements`).

```robotframework
# GOOD — first step auto-waits
Fill Search Query
    [Arguments]    ${query}
    Fill Text    ${SEARCH_INPUT}    ${query}

# GOOD — non-auto-waiting read gated by a wait
Read Visible Course Titles
    Wait For Elements State    ${COURSES_HEADING}    visible
    ${titles}=    Get Elements    ${COURSE_CARD_HEADING}
    RETURN    ${titles}
```

#### Validation at the end

When the last step is an action with no trailing assertion, add a confirmation:

- For navigation: `Get Url    *=    /dashboard` (or `==`) — a clean page boundary marker
- For in-page changes: a simple auto-retrying check on the affected element (`Get Element States`, `Get Text  <sel>  ==  ...`)

This is a **stabilizing** check, not the test's goal assertion — keep it minimal.

```robotframework
# GOOD — URL assertion after navigation
Log In With Credentials
    [Arguments]    ${email}    ${password}
    Fill Text    ${LOGIN_EMAIL}       ${email}
    Fill Text    ${LOGIN_PASSWORD}    ${password}
    Click        ${LOGIN_SUBMIT}
    Get Url      *=    /dashboard

# GOOD — in-page confirmation
Add Course To Cart
    [Arguments]    ${course_name}
    Click       ${CARD}[name="${course_name}"] >> ${ADD_TO_CART}
    Get Text    ${CART_BADGE}    ==    1
```

#### Action keywords vs validation keywords

- **Action keywords** perform user interactions. They may include lightweight stabilizing assertions (start/end guards above, or e.g. confirming a dialog opened before interacting with it).
- **Validation keywords** are dedicated to the test's *goal* assertions and do nothing else. Their names read as assertions (`... Should ...` / `Verify ...`). Parametrize them so multiple tests reuse the same keyword.

```robotframework
# Validation keyword — owns the goal assertion, parametrized
Error Message Should Be
    [Arguments]    ${message}
    Get Text    ${ALERT}    ==    ${message}
```

The test reads as action → action → validation:

```robotframework
*** Test Cases ***
User Sees Error For Invalid Password
    Open Login
    Log In With Credentials    user@example.com    wrong
    Error Message Should Be    Invalid email or password
```

#### Keyword naming

- Descriptive verb phrases — no abbreviations, no acronyms
- Validation keywords read as assertions (`... Should ...` / `Verify ...`)

```
Log In With Credentials       ✅
Fill Checkout Billing Form    ✅
Open First Course In List     ✅
Cart Item Count Should Be     ✅

Login                         ❌ vague
Click Btn                     ❌ abbreviation
Do Login                      ❌ vague verb
```

#### Reuse first

Before adding a new keyword, scan every existing keyword on the relevant page resource. If any covers the flow — use it. If a near-match exists, **parametrize** it (add an argument) rather than duplicating. Never write two keywords that differ only in a hardcoded value.

### 5. Build / extend the aggregator and setup keywords

`resources/pages.resource` is the aggregator: it `Resource`-imports every page resource so suites import one file and get all page keywords. Suites import the aggregator and never import individual page resources directly (unless the project's convention differs). The role entry keywords (`Open Application As Guest`, `Open Authenticated Browser`) live in `resources/common/` and open the browser/context in `Suite Setup`.

If these files don't exist yet, create them:

```robotframework
# resources/pages.resource
*** Settings ***
Resource    pages/login_page.resource
Resource    pages/dashboard_page.resource
```

```robotframework
# resources/common/browser_setup.resource
*** Settings ***
Library    Browser

*** Keywords ***
Open Application As Guest
    New Browser    chromium    headless=${HEADLESS}
    New Context    baseURL=${BASE_URL}    viewport={'width': 1280, 'height': 720}
    New Page

Open Authenticated Browser
    [Arguments]    ${storage_state}
    New Browser    chromium    headless=${HEADLESS}
    New Context    baseURL=${BASE_URL}    storageState=${storage_state}    viewport={'width': 1280, 'height': 720}
    New Page

Close Application
    Close Browser    ALL
```

`${BASE_URL}` and `${HEADLESS}` come from `robot.toml` profiles, not hardcoded. A suite then wires:

```robotframework
*** Settings ***
Resource          ../../resources/pages.resource
Suite Setup       Open Application As Guest
Suite Teardown    Close Application
```

When you add a new page resource:
1. Create `resources/pages/<page_name>.resource`
2. Add a `Resource    pages/<page_name>.resource` line to `resources/pages.resource`

### 6. Refactor the test files

Swap raw Browser calls for domain-keyword calls. **Do not split tests, do not regroup or rename test cases, do not move steps between tests, do not change `Suite Setup`/`Test Setup` structure.** Test structure stays identical — only the body changes.

```robotframework
# Before
*** Settings ***
Library    Browser
Suite Setup    Open Application As Guest

*** Test Cases ***
User Can Log In With Valid Credentials
    Click        role=link[name="Log In"]
    Fill Text    role=textbox[name="Email"]    user@example.com
    Fill Text    label=Password                Password123!
    Click        role=button[name="Login"]
    Get Url      *=    /dashboard

# After
*** Settings ***
Resource    ../../resources/pages.resource
Suite Setup    Open Application As Guest

*** Test Cases ***
User Can Log In With Valid Credentials
    Open Login
    Log In With Credentials    user@example.com    Password123!
```

If a test still needs a raw Browser keyword (e.g. capturing text not yet wrapped in a keyword), prefer adding a keyword to the page resource over leaving raw calls in the suite.

### 7. Run the affected tests

```bash
uv run --env-file .env robotcode run --suite "<Suite Name>"
```

To run a specific test:
```bash
uv run --env-file .env robotcode run --test "<Test Name>"
```

Add `-p <env>` to select an environment profile. If passing → step 9. If failing → step 8.

### 8. Debug

Follow the same trace-driven debug loop as `rf-debug-test`:

#### 8.1 Read the run output

Read the console and the run artifacts in the `output-dir` (`output.xml`, `log.html`). The Browser library captures a failure screenshot (embedded in `log.html`, under `<output-dir>/browser/screenshot/`).

#### 8.2 Inspect the Browser trace via CLI (not GUI)

Capture a trace (`Start Tracing` after `New Context`, `Stop Tracing    ${OUTPUT_DIR}/trace.zip` in teardown) and inspect it non-interactively:

**Important:** Use `npx playwright trace` (CLI), **NOT** `rfbrowser show-trace` (blocking GUI).

```bash
npx playwright trace open <output-dir>/trace.zip
npx playwright trace actions
npx playwright trace action <number>
npx playwright trace snapshot <action-number> --name after
npx playwright trace requests
npx playwright trace errors
npx playwright trace close
```

#### 8.3 Apply the fix

Common refactor failures and the right fix:
- **Selector mismatch** — the source uses different text/role than the original test; fix the selector variable inside the page resource
- **Boundary error** — a keyword does work that belongs on the next page; split it into two keywords on the correct resources
- **Missing start guard** — the keyword starts with a non-auto-waiting read (`Get Text` into a var, `Get Elements`) without a wait; add `Wait For Elements State` first
- **Missing end confirmation** — an action keyword's last step navigates but the keyword doesn't assert the new URL; add `Get Url  *=  ...`

If the failure is in the application (not the test), explain it rather than guessing. Repeat 7–8 until passing.

### 9. Confirm and finalize

Use `AskUserQuestion`:

- Question: "Refactor passes. Does it look right?"
- Header: "Finalize"
- Option 1: label "Looks good", description "Remove leftover comments and finalize"
- Option 2: label "Needs changes", description "Tell me what to adjust"

On **"Looks good"**: remove leftover `# ...` scaffolding comments from the refactored suites/resources (keep `[Documentation]`, settings, and code). Collapse stray blank lines inside test/keyword bodies; keep a single blank line between test cases and between keywords. Then go to step 10.

On **"Needs changes"**: apply the feedback, re-run (step 7), and loop.

### 10. Offer to commit

Use `AskUserQuestion`:

- Question: "Commit the refactor?"
- Header: "Commit"
- Option 1: label "Yes, commit", description "Stage page resources + suite changes and create a commit"
- Option 2: label "No", description "Skip the commit"

On **"Yes, commit"**: run `git status` and `git diff` to review, draft a concise message (e.g. `refactor(tests): move guest suites onto resource-based POM`), stage the new/changed files in `resources/pages/`, `resources/`, and `tests/`, and commit. Match the repo's existing commit style from `git log`.

On **"No"**: stop.

## Anti-patterns (quick reference)

- ❌ Bare selectors scattered through the suite instead of `*** Variables ***` in the page resource
- ❌ Single-action keywords (`Click Login Button`, `Fill Email`)
- ❌ Keywords spanning two pages
- ❌ Action keywords owning the test's goal assertion (use a separate `... Should ...` / `Verify ...` validation keyword)
- ❌ Duplicate keywords that differ only in a hardcoded value (parametrize instead)
- ❌ Renaming the same selector variable across keywords just because the context changed
- ❌ Splitting test cases or moving steps during refactor — structure stays untouched
- ❌ Custom `timeout=` added preemptively (central timeouts belong in `robot.toml`)
- ❌ `Sleep` anywhere — rely on Browser auto-waits and explicit `Wait For*` keywords
- ❌ Suites importing individual page resources directly instead of the `resources/pages.resource` aggregator

---
name: rf-new-test
description: Write a new Robot Framework E2E test (Browser library, optionally RequestsLibrary) from user-provided test steps. Reviews existing suites, inspects source code, writes the test as a domain-keyword-driven suite, then runs and debugs it if needed.
---

Write a new Robot Framework E2E test (Browser library for UI, RequestsLibrary for API) based on the provided test steps.

Test steps: $ARGUMENTS

**Never skip `AskUserQuestion` steps in this skill, even if told to work autonomously.**

## Instructions

### 1. Review existing test suite

Discover the project's layout:

1. Read `robot.toml` at the repo root to find `paths`, `output-dir`, `python-path`, and the environment **profiles** (each profile carries `BASE_URL`/`API_BASE_URL`).
2. Read `tests/__init__.robot` (if present) and the directory layout under `tests/` to understand role folders (`guest/`, `<role>/`, `api/`) and execution order (`00_auth_setup` sorts first).
3. Read existing `.robot` suites under `tests/` to understand:

- What is already covered (avoid duplicating tests)
- Which suite and role folder the new test belongs in
- Conventions in use (naming, `[Tags]`, `Suite Setup`/`Test Setup` patterns)
- Which aggregator the suites import (`resources/pages.resource` for UI, `resources/api.resource` for API)
- Which setup keyword establishes the session (`Open Application As Guest`, `Open Authenticated Browser    ${EXECDIR}/.auth/<role>.json`, or `Create Api Session`)

Read the architecture and scripting rules (`.claude/rules/robotframework-architecture.md` and `.claude/rules/robotframework-scripting.md`, or `.cursor/rules/`) and follow them.

### 2. Inspect application source code

For each page or component involved in the test steps:

- Read the source code of the relevant page component and the child components that render the elements you interact with or assert on
- Choose selectors using the priority from the scripting rule: `role=` > `text=` > `[data-testid="..."]` > `id=` > `css=`/`xpath=` (structural tags only)
- If no reliable user-visible selector exists, **add a `data-testid` attribute to the application source code**, then target `[data-testid="..."]`

### 3. Write the test

- Place the suite in the correct role folder (`tests/<role>/<feature>.robot`), or add a test case to an existing suite when an appropriate one exists — don't create a new suite when one already fits.
- Import the aggregator (`Resource    ../../resources/pages.resource` for UI; add `../../resources/api.resource` if the test also touches the API).
- Wire `Suite Setup`/`Test Setup` to the right entry keyword for the role (guest vs authenticated vs API) and a `Suite Teardown`/`Test Teardown` that tears down (`Close Application` / `Delete All Sessions`).
- **Every UI test starts from the home page (`/`)** via the setup keyword — never open an inner page directly. Reach inner pages through UI interactions (domain keywords that click links/buttons).
- **Tests call tier-3 domain/service keywords only** — never raw `Click`, `Fill Text`, `GET On Session` in a test body (architecture rule). If a keyword for the flow doesn't exist, add it to the relevant page/service resource (or parametrize a near-match), then register the page resource in `resources/pages.resource`.
- Follow the scripting rule (selectors as `*** Variables ***`, asserting `Get*` keywords, no `Sleep`, `VAR` syntax for variable creation, no preemptive `timeout=`).
- The test's **goal** assertion lives in a dedicated `... Should ...` / `Verify ...` keyword on the page/service resource — not inline in the suite and not inside an action keyword.
- Each test verifies one logical user flow.
- **Test naming** — Title Case describing user behavior: `User Can Log In With Valid Credentials`, `User Sees Error For Invalid Password`.
- Tag the suite/test with `[Tags]` (or suite-level `Test Tags`) for selective execution.

#### Suite template

```robotframework
*** Settings ***
Resource          ../../resources/pages.resource
Suite Setup       Open Application As Guest
Suite Teardown    Close Application
Test Tags         <feature>    <role>

*** Test Cases ***
<Test Name In Title Case>
    # action → action → validation, all via domain keywords
```

If the test belongs in an existing suite, add the test case there. If a page has enough interactions to warrant its own resource and none exists, create `resources/pages/<page_name>.resource`, add a `Resource` line for it to `resources/pages.resource`, and use its keywords. If a near-match keyword exists, parametrize it rather than duplicating.

### 4. Update `robot.toml` / structure if needed

Execution order comes from directory names and `paths` in `robot.toml`; new suites under existing role folders need no config change. If you introduce a brand-new role folder, make sure it's covered by `paths` (usually `paths = ["tests"]` already covers it) and that a corresponding auth/setup path exists if the role is authenticated.

### 5. Ask user to run or adjust

Use the `AskUserQuestion` tool:

- Question: "Test is ready. What would you like to do next?"
- Header: "Next step"
- Option 1: label "Run the test", description "Execute the test and debug if it fails"
- Option 2: label "Something else", description "Tell me what you'd like to change"

If the user selects "Run the test", proceed to step 6. Otherwise follow their instructions.

### 6. Run the test

Run only the new test by name with RobotCode (paths, output dir, and env profile come from `robot.toml`):

```bash
uv run --env-file .env robotcode run --test "<Test Name>"
```

Select the environment profile with `-p <env>` when needed (e.g. `uv run --env-file .env robotcode -p qa run --test "<Test Name>"`). To scope to a suite, add `--suite "<Suite Name>"` or pass the suite path.

If the test **passes**, proceed to step 8. If it **fails**, proceed to step 7.

### 7. Debug

#### 7.1 Read the run output

RobotCode/Robot Framework writes `output.xml`, `log.html`, and `report.html` to the `output-dir` from `robot.toml` (e.g. `results/`). Read the console output and the failing keyword's message. The Browser library's default `run_on_failure` captures a screenshot, embedded in `log.html` and saved under the output dir's `browser/screenshot/`.

#### 7.2 Inspect the Browser trace (deep failures)

For hard failures, capture a Playwright trace. If the project's browser setup doesn't already trace, add `Start Tracing` after `New Context` and `Stop Tracing    ${OUTPUT_DIR}/trace.zip` in teardown, then re-run. Inspect the trace **non-interactively** with the Playwright trace CLI (the Browser library produces standard Playwright traces):

```bash
npx playwright trace open <output-dir>/trace.zip
npx playwright trace actions          # failures marked with ✗
npx playwright trace action <number>
npx playwright trace snapshot <action-number> --name after
npx playwright trace requests
npx playwright trace errors
npx playwright trace close
```

Avoid `rfbrowser show-trace` here — it opens a blocking GUI. (See the `rf-debug-test` skill for the full trace workflow.)

#### 7.3 Report findings

Summarize: **what went wrong** (selector didn't match, assertion mismatch, timeout, API/data issue), **evidence** (error message, expected vs actual, what the snapshot/screenshot showed), and the **failing line** in the suite/resource (`path:line`).

#### 7.4 Apply the fix

If the root cause is clear (wrong selector, wrong expected value, missing wait/precondition), fix the test or the page/service keyword and re-run:

```bash
uv run --env-file .env robotcode run --test "<Test Name>"
```

If the issue is in the application (not the test), explain it rather than guessing. Repeat 6–7 until the test passes or the issue needs user input, then go to step 8.

### 8. Confirm and finalize

Use `AskUserQuestion`:

- Question: "Test passed. Does it meet your expectations?"
- Header: "Finalize"
- Option 1: label "Looks good", description "Remove scaffolding comments and finalize the test"
- Option 2: label "Needs changes", description "Tell me what should be adjusted"

If **"Looks good"**: remove leftover `# ...` scaffolding comments from the suite/resources (keep `[Documentation]`, settings, and code), collapse stray blank lines inside test/keyword bodies, and keep a single blank line between test cases/keywords. Then proceed to step 9.

If **"Needs changes"**: apply the instructions, re-run (step 6), and loop.

### 9. Offer to commit

Use `AskUserQuestion`:

- Question: "Should I commit the new test?"
- Header: "Commit"
- Option 1: label "Yes, commit", description "Stage the changes and create a commit"
- Option 2: label "No", description "Skip the commit"

If **"Yes, commit"**: run `git status` and `git diff` to review, draft a concise message describing the flow the test covers, stage the relevant files (suite + any page/service resources + aggregator), and commit, matching the repo's existing commit style from `git log`.

If **"No"**: follow the user's instructions and stop.

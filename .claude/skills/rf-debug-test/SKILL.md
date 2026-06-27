---
name: rf-debug-test
description: Debug a failed Robot Framework test (Browser library) by running it, reading the Robot log/report, and analyzing the Playwright trace with the trace CLI (`npx playwright trace`). Use whenever the user asks to debug, fix, or investigate a failing or flaky Robot Framework test, or when a run produces an error. Also triggers on "this test is broken", "why is this test failing", "fix this test", "investigate test failure".
---

# Debug a Failed Robot Framework Test (Browser library)

You are debugging a Robot Framework E2E test that uses the Browser library. Follow these steps in order.

## Step 0: Confirm the test name

The user must provide the test to debug — the exact test case name or a unique keyword from it.

If the user did **not** provide one, **stop and ask**:

> Which Robot Framework test should I debug? Please paste the exact test case name (e.g. `User Can Log In With Valid Credentials`) or a unique keyword from it.

Do not guess, do not pick the most recently edited test, do not run the entire suite. Wait for the answer.

## Step 1: Find the test in the project

This skill is project-agnostic. Discover the layout:

1. Read `robot.toml` to find `paths`, `output-dir`, `python-path`, and the environment profiles.
2. Search the `tests/` tree for the supplied name/keyword under `*** Test Cases ***` headings (and resource keywords if the name refers to a keyword). 
3. If multiple matches are found, list them and ask which to debug. If none, tell the user and stop — do not invent a test.

Read the matched suite in full so you understand its `Suite Setup`/`Test Setup`, imported resources (`pages.resource`/`api.resource`), the role entry keyword, and what the test is meant to do before running it.

## Step 2: Run the test with tracing on

Run only the matched test with RobotCode (config comes from `robot.toml`):

```bash
uv run --env-file .env robotcode run --test "<Test Name>"
```

Add `-p <env>` to select an environment profile, or `--suite "<Suite>"` / a path to scope.

Read the console output and the run artifacts in the `output-dir` (default `results/`): `output.xml`, `log.html`, `report.html`.

- If the test **passes**, tell the user it passed on this run, note it may be flaky, and stop. Do not open a trace for a passing run.
- If the test **fails**, extract the failing keyword, the error/assertion message, and the location (`suite.robot` / `resource.resource` line). The Browser library's default `run_on_failure` saves a screenshot (embedded in `log.html`, also under `<output-dir>/browser/screenshot/`).

To inspect details non-interactively, read `log.html` or query `output.xml` (e.g. with `rg`/`xmllint`) for the `FAIL` message rather than opening the Robot log viewer GUI.

### Capture a Playwright trace

For deep failures, ensure a trace is captured. If the project's browser setup doesn't already trace, temporarily add tracing around the context:

```robotframework
# After New Context (e.g. in Open Application As Guest / Open Authenticated Browser)
Start Tracing
# In teardown, before Close Browser
Stop Tracing    ${OUTPUT_DIR}/trace.zip
```

Re-run the single test so the trace zip is produced under the output dir.

## Step 3: Analyze the trace with the CLI

The Browser library produces **standard Playwright traces**, so the Playwright trace CLI works directly.

**Important:** Use `npx playwright trace` (CLI), **NOT** `rfbrowser show-trace` or `npx playwright show-trace` — those open a blocking GUI.

If `npx` is unavailable, the Browser library bundles a Playwright node CLI; you can also fall back to reading `log.html` and the failure screenshot.

### 3.1 Open the trace

```bash
npx playwright trace open <output-dir>/trace.zip
```

### 3.2 List actions and locate the failure

```bash
npx playwright trace actions
```

Look for actions marked with `✗`. Narrow down with a filter:

```bash
npx playwright trace actions --grep="expect"
```

### 3.3 Inspect the failing action

```bash
npx playwright trace action <number>
```

Shows the action type, error message, expected vs received values, timeout, and available snapshots.

### 3.4 View the page snapshot at the moment of failure

```bash
npx playwright trace snapshot <action-number> --name after
```

Use `--name before` for the state right before the action. The `after` snapshot is usually most useful for failed assertions and missing elements.

### 3.5 Check network requests (when relevant)

```bash
npx playwright trace requests
npx playwright trace request <request-id>
```

### 3.6 Check console messages and page errors

```bash
npx playwright trace console
npx playwright trace errors
```

### 3.7 Close the trace when done

```bash
npx playwright trace close
```

## Step 4: Report findings

Give a clear, structured summary:

- **Which test failed** — suite + exact test case name (e.g. `tests/guest/login.robot` → `User Sees Error For Invalid Password`).
- **What went wrong** — root cause (selector didn't match, assertion mismatch, timeout, network/API failure, missing test data, navigation issue, etc.).
- **Evidence** — the specific error message, expected vs received, and what the snapshot/screenshot revealed.
- **Failing line** — exact location in `path:line` format (suite or resource keyword).
- **Suggested fix** — a concrete change or next step.

Distinguish *test bugs* (wrong selector, wrong expectation, missing wait), *application bugs* (the app is genuinely broken), and *environment problems* (missing seed data, missing `.env`/auth state, wrong profile). Do not silently "fix" an application bug by weakening the test.

## Step 5: Apply the fix

If the root cause is clear and lives in the test (wrong selector, incorrect expected value, wrong URL, missing precondition), fix the suite or the relevant page/service resource keyword and re-run only that test:

```bash
uv run --env-file .env robotcode run --test "<Test Name>"
```

If the fix is **not** straightforward — application bug, ambiguous root cause, missing test data, env/profile issue, or a flake needing broader investigation — explain the situation and propose next steps. Do not paper over real bugs with `Sleep`, preemptive `timeout=` overrides, or `force=True` on actions.

## Reference: `npx playwright trace` subcommands

| Command | Purpose |
|---|---|
| `open <trace>` | Open a trace zip file for CLI inspection |
| `close` | Close the currently open trace |
| `actions [options]` | List all actions (use `--grep` to filter) |
| `action <id>` | Show details of a specific action |
| `requests [options]` | List network requests |
| `request <id>` | Show details of a specific request |
| `console [options]` | Show console messages |
| `errors` | Show errors with stack traces |
| `snapshot [options] <id>` | View DOM snapshot for an action |
| `screenshot [options] <id>` | Save a screenshot for an action |
| `attachments` | List trace attachments |
| `attachment [options] <id>` | Extract a specific attachment |
| `help [command]` | Show help for a command |

## Reference: capturing a trace in the Browser library

| Need | Keyword |
|---|---|
| Start recording a trace | `Start Tracing` |
| Save the trace to a zip | `Stop Tracing    ${OUTPUT_DIR}/trace.zip` |
| Failure screenshot (automatic) | Browser default `run_on_failure` = `Take Screenshot` |
| Wait for an element state | `Wait For Elements State    <selector>    visible|hidden|detached` |
| Capture an async response | `Promise To    Wait For Response    matcher=...` → `Wait For    ${promise}` |

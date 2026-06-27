# Initialize Robot Framework Scripting Rule

Write the Robot Framework scripting rule to `.claude/rules/robotframework-scripting.md` in the current project. The rule auto-loads when Claude touches files matching `tests/**`, `resources/**`, `libraries/**`, `*.robot`, `*.resource`, or `robot.toml`.

## Target File

`.claude/rules/robotframework-scripting.md`

## Workflow

1. **Verify project context** — cwd should be a Robot Framework project managed with `uv`. Look for `pyproject.toml`/`uv.lock` (listing `robotframework`, `robotframework-browser`, and `robotframework-requests`) or existing `*.robot`/`*.resource` files. Otherwise stop and tell the user.
2. **Ensure `.claude/rules/` exists** — `mkdir -p .claude/rules`.
3. **Check for existing file**:
   - **Not present** → write the content from the `<!-- RULES_START -->` block below, then report `Created .claude/rules/robotframework-scripting.md`.
   - **Present and identical** → report `Already up to date` and exit.
   - **Present and different** → use `AskUserQuestion` with options: **Overwrite / Show diff / Skip**.
     - **Overwrite** → write content, report `Updated .claude/rules/robotframework-scripting.md`.
     - **Show diff** → run `git diff --no-index .claude/rules/robotframework-scripting.md <temp-file-with-new-content>`, then re-prompt **Overwrite / Skip**.
     - **Skip** → leave existing file untouched, report `Skipped — kept existing file`.
4. **Do NOT** touch `CLAUDE.md`. Rules in `.claude/rules/*.md` auto-load via path frontmatter; explicit `@` imports are redundant.

## Content to write

Everything between `<!-- RULES_START -->` and `<!-- RULES_END -->` (exclusive of the markers) is the verbatim file content, including the rule's own frontmatter.

<!-- RULES_START -->
---
description: Robot Framework Browser (+ RequestsLibrary) scripting conventions - selectors, assertions, waiting, suite/test structure, naming, keyword style, actions, and form interactions
paths: [tests/**,resources/**,libraries/**,**/*.robot,**/*.resource,robot.toml]
---

# Robot Framework Scripting Rules

Use the **Browser** library (Playwright-based) for UI and **RequestsLibrary** for API. These rules govern how selectors, assertions, and keywords are written inside page/component resources and suites. The Browser library uses Playwright's selector engine, so selector choice mirrors Playwright locator priority.

Project config (paths, environment profiles, and default variables like `BASE_URL`/`HEADLESS`) lives in `robot.toml`, and suites run via `uv run --env-file .env robotcode run` (see the architecture rule). These authoring rules apply regardless of how the run is invoked.

## Selectors

Per the architecture rule, every selector lives as a variable in the owning page/component resource's `*** Variables ***` section. These rules describe how to choose the **selector string** assigned to that variable.

### Selector Strategy Priority (Highest to Lowest)

1. **`role=`** — buttons, links, headings, textboxes, checkboxes (primary approach). Always pass the accessible name: `role=button[name="Login"]`. Labeled form inputs are matched here too, because the `<label>` supplies the accessible name (`role=textbox[name="Email"]`)
2. **`text=`** — static, non-interactive text (paragraphs, spans, list/link text): `text=Welcome back`
3. **`[data-testid="..."]`** — when role/text can't produce a unique, reliable selector. When `data-testid` is needed but missing, **add it to the application component source** rather than using a fragile alternative. Exhaust role and text first — but **always prefer adding `data-testid` over CSS class or structural-path selectors**
4. **`id=`** — stable, unique `id` attributes: `id=submit-btn`
5. **`css=` / `xpath=`** — lowest priority. Acceptable **only** for stable structural tags used as scope (`header`, `nav`, `section`, `footer`). **Never use styling class names** (`css=.font-bold`, `css=.grid > div`) — add a `data-testid` to the source instead

```robotframework
*** Variables ***
# GOOD: role-based (survives UI refactoring)
${LOGIN_EMAIL_INPUT}      role=textbox[name="Email"]
${LOGIN_SUBMIT_BUTTON}    role=button[name="Login"]
${LOGIN_HEADING}          role=heading[name="Login to your account"]
# GOOD: text for non-interactive content
${WELCOME_BANNER}         text=Welcome back
# GOOD: data-testid when role/text are not unique
${PRICING_CARD}           [data-testid="pricing-card"]
# GOOD: structural tag as scope only
${PAGE_HEADER}            css=header
# BAD: styling classes (break on design changes) — add a data-testid instead
# ${ERROR_BOX}            css=.bg-destructive
# ${FIRST_INPUT}          css=div > form > input:first-child
```

### Common ARIA Roles for role=

Only use roles that actually exist on the page. Some HTML elements have **implicit roles** that depend on context:

| Role | HTML Element | Notes |
|------|-------------|-------|
| `button` | `<button>`, `<input type="submit">` | Always works |
| `link` | `<a href="...">` | Must have `href` |
| `heading` | `<h1>`–`<h6>` | Use `[level=1]` to target a specific level: `role=heading[level=1]` |
| `textbox` | `<input type="text">`, `<textarea>` | Also `type="email"`, `type="password"` |
| `checkbox` | `<input type="checkbox">` | Always works |
| `combobox` | `<select>` | Always works |
| `navigation` | `<nav>` | Always works — **use this to scope to nav menus** |
| `dialog` | Modals, sheets, drawers | Set via `role="dialog"` attribute |
| `tab` | Tab components | Set via `role="tab"` attribute |
| `table`, `row`, `cell` | `<table>`, `<tr>`, `<td>` | Always works |
| `article` | `<article>` | Always works |
| `banner` | `<header>` | **Only when `<header>` is a direct child of `<body>`** — not when nested inside `<section>`, `<article>`, `<aside>`, `<main>`, or `<nav>` |
| `contentinfo` | `<footer>` | Same rule as `banner` — only as a direct child of `<body>` |
| `region` | `<section>` | **Only when `<section>` has an accessible name** (via `aria-label`/`aria-labelledby`) |

**When `role=banner` / `role=contentinfo` won't match** (header/footer nested inside sections), use a structural CSS selector instead:

```robotframework
*** Variables ***
# BAD: header nested inside <section>, so banner role doesn't apply
${BLOG_LINK}    role=banner >> role=link[name="Blog"]
# GOOD: structural tag for the <header>
${BLOG_LINK}    css=header >> role=link[name="Blog"]
# GOOD: scope to <nav>, which always has the navigation role
${BLOG_LINK}    role=navigation >> role=link[name="Blog"]
```

### Selector Text Must Match Source Exactly

When reading source to build selectors, use the **exact text** in `name=`/`text=`. Never paraphrase. Watch for **responsive variants** — the same component may render different text/elements at different viewports (e.g., Tailwind `hidden md:flex`). Match the variant **visible at the test viewport** (Desktop Chrome by default).

```robotframework
*** Variables ***
# Source has "View Details" (mobile) and "Details" (desktop); tests run desktop
# GOOD: desktop-visible element
${DETAILS_BUTTON}    role=button[name="Details"]
# BAD: mobile element, hidden at desktop viewport
# ${DETAILS_BUTTON}  role=button[name="View Details"]
```

### Selector Uniqueness

Browser runs in **strict mode**: action keywords (`Click`, `Fill Text`, `Check Checkbox`, `Select Options By`) fail if the selector resolves to more than one element. Verify uniqueness against the source; narrow by chaining with `>>`. When a selector intentionally returns many elements (collecting list items, rows, cards), uniqueness is not required — use `Get Elements`, `Get Element Count`, or `>> nth=`.

```robotframework
*** Variables ***
# GOOD: scoped to navigation — resolves to one element
${PRODUCTS_LINK}    role=navigation >> role=link[name="Products"]
# BAD: matches multiple "Learn More" links — Click will fail in strict mode
# ${LEARN_MORE}     role=link[name="Learn More"]
# GOOD: a collection for iteration/counting
${ARTICLE_CARDS}    role=article
```

```robotframework
*** Keywords ***
Article Count Should Be Three
    Get Element Count    ${ARTICLE_CARDS}    ==    3
```

### Scoping to Containers (Avoiding False Positives)

When a page repeats UI patterns (pricing cards, product rows, list items), **scope interactions and assertions to the specific container** via `>>` — never rely on an unscoped selector that could match an element from another section. A false positive happens when the intended element is missing but the selector silently matches a different one elsewhere, making the test pass incorrectly.

```robotframework
*** Variables ***
${PRICING_CARD}           [data-testid="pricing-card"]
${CART_ITEM_PRICE}        [data-testid="cart-item-price"]
${ADD_TO_CART_BUTTON}     role=button[name="Add to Cart"]

*** Keywords ***
Add First Plan To Cart
    [Documentation]    Scopes to the first pricing card, then clicks within it.
    Click    ${PRICING_CARD} >> nth=0 >> ${ADD_TO_CART_BUTTON}

Cart Item Price Should Be
    [Documentation]    Scopes the price to the cart item, not the order total.
    [Arguments]    ${expected_price}
    Get Text    role=dialog >> ${CART_ITEM_PRICE}    ==    ${expected_price}
```

**Rule of thumb:** if a selector uses `nth=` or matches a generic name like "Remove", "Add to Cart", "Submit", it likely needs a parent scope. When the parent has no semantic role or unique text, **add a `data-testid`** to the source rather than using CSS class selectors.

### Semantic Scoping (Asserting Relationships)

Scoping also validates that an element appears in the **correct logical context**. Even when a value is unique, scope it to its meaningful parent when the test verifies a relationship.

**Key question:** "If this value moved to a different section, would that be a bug?" If yes, the assertion must pin it to the correct section. Use `>>` chaining and `:has-text(...)` to express parent–child relationships.

```robotframework
*** Variables ***
${SUMMARY_PANEL}    [data-testid="summary-panel"]
${USER_TAG}         [data-testid="user-tag"]

*** Keywords ***
Summary Should Show Progress
    [Arguments]    ${progress_text}
    # BAD: text anywhere on the page — passes even if it rendered in the wrong section
    # Get Text    text=${progress_text}    !=    ${EMPTY}
    # GOOD: scoped to the section it belongs to
    Get Text    ${SUMMARY_PANEL}    *=    ${progress_text}

User Tag Should Show Owner Badge
    [Arguments]    ${owner_email}
    # GOOD: scoped to the specific user's tag via :has-text()
    Get Text    ${USER_TAG}:has-text("${owner_email}")    *=    Owner
```

### Cross-Page Content Linking

When an action navigates from one page to another and the destination shows content related to the source (clicking a product card opens that product's page), **capture a value from the source page and assert it on the destination**. This proves the user landed on the *right* page, not just *a* page of the same type. Capturing a value (no assertion operator) returns immediately, so capture it while still on the source page.

```robotframework
*** Keywords ***
Open Item Detail And Confirm Title
    [Documentation]    Captures the list item's name, opens it, asserts it on the detail page.
    # BAD: asserts any level-1 heading exists — passes even if the wrong item opened
    # Get Element States    role=heading[level=1]    *=    visible
    ${item_name_value}=    Get Text    ${LIST_ITEM_HEADING}
    Click    ${LIST_ITEM_DETAILS_LINK}
    Get Text    role=heading[level=1]    ==    ${item_name_value}
```

This applies whenever navigation creates a logical link: list item → detail page, article title → article page, order row → order detail.

### Chaining and Filtering

Prefer the `name=` argument inside `role=` for filtering. Chain with `>>` to narrow scope, `:has-text(...)` for parent–child relationships, and `>> nth=` only when text-based scoping is impossible.

```robotframework
*** Variables ***
# GOOD: name argument for role filtering (preferred)
${SUBMIT_BUTTON}      role=button[name="Submit"]
${COURSES_LINK}       role=link[name="Courses"]
# GOOD: :has-text() to scope a section by its content
${TEAM_SECTION}       css=section:has-text("About the Team")
# GOOD: chain to narrow scope
${FEATURED_VIEW_ALL}  css=section:has-text("Featured Items") >> role=link[name="View All"]
# BAD: index when text-based scoping is possible — ${TEAM_SECTION}  css=section >> nth=0
```

## Assertions

### Inline Assertion Operators (Auto-Retrying)

Browser `Get*` keywords act as assertions **when an operator is supplied**, polling until the condition is met or the timeout elapses. Always prefer these. Operators: `==`, `!=`, `>`, `<`, `>=`, `<=`, `contains` (`*=`), `not contains`, `starts`, `ends`, `matches`, `validate`.

```robotframework
*** Keywords ***
Dashboard Should Be Loaded
    Get Url             *=    /dashboard
    Get Title           ==    Dashboard
    Get Text            role=heading[name="Dashboard"]    ==    Dashboard
    Get Element Count   ${LIST_ITEMS}    ==    5
    Get Element States  ${SUBMIT_BUTTON}    *=    visible    enabled
```

Prefer an asserting `Get Text ... ==` on a precise selector over checking visibility of a text match.

### Generic Assertions (No Retry)

Avoid capturing a value and comparing it with `Should Be Equal` for UI state — it does not retry and is race-prone. (Capturing values is fine for non-UI data like cross-page linking or API bodies.)

```robotframework
*** Keywords ***
Header Should Greet User
    # BAD: capture + generic compare — no retry
    # ${text}=    Get Text    css=header
    # Should Be Equal    ${text}    Welcome back
    # GOOD: inline assertion auto-retries
    Get Text    css=header    *=    Welcome back
```

### Negative Assertions

After an action that triggers a DOM change, **wait for the change to settle before asserting absence** to avoid false positives.

```robotframework
*** Keywords ***
Delete Dialog Should Close
    Click    role=button[name="Delete"]
    # GOOD: wait for the API to finish, then assert the dialog is gone
    ${promise}=    Promise To    Wait For Response    matcher=**/api/**    timeout=10s
    Wait For    ${promise}
    Wait For Elements State    role=dialog    hidden
```

### No "Continue On Failure"

Do not wrap assertions in `Run Keyword And Continue On Failure` or other soft-assert patterns. Every assertion should fail the test immediately.

## Waiting

### Browser Auto-Waits on Actions

`Click`, `Fill Text`, `Check Checkbox`, `Select Options By` auto-wait for actionability and auto-scroll. Do **not** add explicit waits before them.

```robotframework
# GOOD: auto-waits for the element to be ready
Click    ${SUBMIT_BUTTON}
# BAD: redundant wait before an auto-waiting action
# Wait For Elements State    ${SUBMIT_BUTTON}    visible
# Click    ${SUBMIT_BUTTON}
```

### When You Need Explicit Waits

Asserting `Get*` keywords (operator supplied) already auto-retry. Add explicit waits only for **non-asserting reads** or **async** flows:

- `Get*` **without** an operator returns instantly — gate with `Wait For Elements State` first if needed
- `Wait For Elements State    ${SELECTOR}    visible|hidden|detached|enabled`
- `Wait For Load State    networkidle`
- HTTP responses — start the wait **before** the triggering action with the `Promise To` pattern
- `Wait For Condition    <Getter without "Get">    ...` to poll any assertion

```robotframework
# GOOD: capture the response that the click triggers
${promise}=    Promise To    Wait For Response    matcher=**/api/orders    timeout=15s
Click    ${SAVE_BUTTON}
${response}=    Wait For    ${promise}

# GOOD: poll an assertion until true
Wait For Condition    Text    id=status    contains    Done
```

### Never Use Sleep

```robotframework
# BAD: slow, unreliable, hides real issues
# Sleep    3s
```

Rely on auto-waiting actions and asserting `Get*` keywords instead.

### No Custom Timeouts by Default

Rely on the library default (`Set Browser Timeout` set once in browser setup, optionally driven by a `robot.toml` variable). Do not add per-keyword `timeout=` to assertions or waits preemptively. Custom timeouts are allowed **only as a debugging fix** when investigation confirms the default is genuinely insufficient for a step — never in the first draft.

## Suite / Test Structure

### Naming Convention

Test (and `... Should ...` keyword) names describe **user behavior**, not implementation. Use Title Case.

```robotframework
*** Test Cases ***
# GOOD
User Can Log In With Valid Credentials
    [Documentation]    ...
User Sees Error For Invalid Password
    [Documentation]    ...
# BAD: implementation-focused — "Test Login", "POST /api/auth Returns 200"
```

### Always Start From the Home Page

Every test starts from the home page (`/`) and reaches inner pages via UI interactions. Never open an inner page directly.

```robotframework
*** Settings ***
Resource       ../../resources/pages.resource
Test Setup     Open Application As Guest    # opens New Page    /

*** Test Cases ***
User Can Log In With Valid Credentials
    Open Login                 # clicks the header Log In link
    Log In With Credentials    user@example.com    Password123!
```

```robotframework
# BAD: navigating straight to an inner page
# Test Setup    New Page    ${BASE_URL}/login
```

### Grouping and Tags

One suite per feature. Tag suites/tests for selective runs.

```robotframework
*** Settings ***
Resource       ../../resources/pages.resource
Test Setup     Open Application As Guest
Test Tags      login    guest

*** Test Cases ***
User Can Log In With Valid Credentials
    ...
User Sees Error For Invalid Password
    ...
```

### One Logical Flow Per Test

Each test verifies one user journey. Push shared setup into `Suite Setup`/`Test Setup`; don't combine unrelated assertions into one test.

## Keyword and Test Code Style

### Selectors Always as Variables

Unlike inline-locator frameworks, Robot Framework selectors are **always** named in the owning resource's `*** Variables ***` section — never hardcoded inline in keywords. This is the single source of truth per page.

### data-testid Naming

`data-testid` values name the **element** (a noun: `button`, `badge`, `checkmark`, `input`, `dialog`), not a state or action. Use `<subject>-<descriptor>-<element>`.

```robotframework
*** Variables ***
# BAD: ends with a state — doesn't say what element this is
# ${LESSON_DONE}    [data-testid="lesson-completed"]
# GOOD: includes the element the testid points to
${LESSON_DONE_CHECKMARK}    [data-testid="lesson-completed-checkmark"]
```

### Reuse Selector Variables

Selectors re-resolve against the live DOM on every use. Reuse the same variable across all phases of a flow (including after navigation or data refresh). Never declare variant names like `${COURSE_CARD_AFTER_UPDATE}`.

### Variable Naming

Use descriptive names — no abbreviations or acronyms. Selector constants are `SCREAMING_SNAKE_CASE`; captured locals are lowercase and named after **what they hold**. When a getter extracts text, suffix the variable with `_value`/`_values` (not `_link`/`_heading`, which imply selectors).

```robotframework
# BAD: abbreviation + name implies a locator but holds a string
# ${toc_links}=    Get Text    ${TOC_NAV}
# GOOD: "_value" reflects the extracted string
${table_of_contents_value}=    Get Text    ${TOC_NAV}
```

### Creating Variables — Use `VAR`

Use Robot Framework's native `VAR` syntax (RF 7+) to create local or scoped variables inside keywords and tests. Do **not** use `Set Variable`, `Set Test Variable`, `Set Suite Variable`, or `Set Global Variable`.

- **Keyword-return assignment stays as normal assignment** — `${response}=    GET On Session    api    /users/${id}`.
- **Use `VAR` for literal or constructed values**, and set lifetime with `scope=` (`LOCAL` default; also `TEST`, `SUITE`, `SUITES`, `GLOBAL`) instead of the legacy `Set * Variable` keywords.
- Works for scalars, lists (`@{}`), and dicts (`&{}`).

```robotframework
# BAD: legacy Set * keywords
# ${greeting}=          Set Variable    Hello
# Set Suite Variable    ${BASE_TITLE}    Dashboard

# GOOD: VAR syntax
VAR    ${greeting}      Hello
VAR    ${base_title}    Dashboard    scope=SUITE
VAR    @{roles}         student    admin
VAR    &{payload}       name=Ada    email=ada@example.com
```

## Actions

### Repeated Clicks on the Same Element

When the same element is clicked several times in a row (stepping a counter), pass `clickCount` to one `Click` instead of repeating the line.

```robotframework
# BAD: repeated identical clicks
# Click    role=button[name="Increase quantity"]
# Click    role=button[name="Increase quantity"]
# GOOD: single call with clickCount
Click    role=button[name="Increase quantity"]    clickCount=2
```

Use this only when the **exact same selector** is clicked consecutively with nothing in between. If the element may change/disappear between clicks, keep them on separate lines so each re-resolves.

## Form Interactions

```robotframework
# Text input — Fill Text clears any existing value automatically
Fill Text    role=textbox[name="Email"]    user@example.com
# Password
Fill Text    role=textbox[name="Password"]    Password123!
# Select dropdown — by label, value, or index
Select Options By    role=combobox[name="Country"]    label    United States
# Checkbox
Check Checkbox    role=checkbox[name="Remember me"]
# Retype — no clear() needed; Fill Text replaces the value
Fill Text    role=textbox[name="Search"]    new query
# Type character by character (autocomplete/debounce)
Type Text    role=textbox[name="Search"]    query    delay=100ms
```

## API Scripting (RequestsLibrary)

For API steps, follow the architecture rule: wrap requests in service keywords, never raw `GET On Session`/`POST On Session` in a test body.

- **Assert status explicitly** with `Status Should Be`; pass `expected_status` when a non-2xx is expected
- **Build bodies with `Create Dictionary`** (from `Collections`); never hardcode duplicated payloads
- **Capture + `Should Be Equal`** is correct for response data (unlike UI state, an API body does not change after the call)
- **One session per suite** via `Create Session`; `Delete All Sessions` in teardown

```robotframework
*** Keywords ***
Created User Email Should Be
    [Arguments]    ${user_id}    ${expected_email}
    ${response}=    GET On Session    api    /users/${user_id}
    Status Should Be    200    ${response}
    Should Be Equal    ${response.json()}[email]    ${expected_email}
```

<!-- RULES_END -->

## Notes

- The `@` symbol at the start of a line is treated as a file import by Claude Code — escape with `\@` in prose if it ever appears (none in current content).
- A leading `#` starts a comment in a Robot Framework data cell. When a selector needs a literal `#` (an `id` shorthand), prefer the `id=` or `css=#...` strategy, or escape it as `\#`.
- This skill is **self-contained**: the rule lives inside `SKILL.md`, so it works on any machine.
- To update the rule across projects, update this `SKILL.md` once, then re-run the skill in each project.

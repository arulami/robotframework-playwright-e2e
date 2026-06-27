# robotframework-playwright-e2e

End-to-end test suite built with [Robot Framework](https://robotframework.org/). UI tests use the
[**Browser** library](https://robotframework-browser.org/) (Playwright-based); API tests use
[**RequestsLibrary**](https://github.com/MarketSquare/robotframework-requests). The project is managed
with [`uv`](https://github.com/astral-sh/uv) and configured/run through
[RobotCode](https://robotcode.io/) (`robot.toml`).

The default profile targets the [SauceDemo](https://www.saucedemo.com) demo application.

## Stack

| Concern        | Tool                                            |
| -------------- | ----------------------------------------------- |
| Test framework | Robot Framework 7                               |
| UI automation  | Browser library (Playwright)                    |
| API automation | RequestsLibrary                                 |
| Runner / config| RobotCode (`robot.toml`)                        |
| Env management | uv                                              |

## Prerequisites

- [uv](https://github.com/astral-sh/uv) installed
- Python (pinned via `.python-version`)

## Setup

```bash
# Install the locked dependency set
uv sync

# Install Playwright browsers for the Browser library
uv run rfbrowser init

# Copy the secrets template and fill in values
cp .env.example .env
```

## Running tests

Configuration (paths, output dir, environment profiles, `BASE_URL` / `API_BASE_URL` / `HEADLESS`)
lives in `robot.toml`. Secrets live in a gitignored `.env` (template: `.env.example`), loaded with
`--env-file`.

```bash
# All suites, default (saucedemo) profile
uv run --env-file .env robotcode run

# Headed mode, single suite
uv run --env-file .env robotcode run --variable HEADLESS:False tests/guest

# Run by tag
uv run --env-file .env robotcode run -i smoke
```

Results (`log.html`, `report.html`, `output.xml`) are written to `results/` (gitignored).

## Layout

```
tests/
  guest/            # UI suites for the guest role (login, checkout, smoke)
  api/              # API suites (smoke)
resources/
  pages.resource    # single UI import surface (aggregator)
  api.resource      # single API import surface (aggregator)
  pages/            # page object resources (login, inventory, cart, checkout)
  keywords/         # browser_setup + api_setup (lifecycle/session)
libraries/          # Python helper keywords (created on demand)
robot.toml          # RobotCode config: paths, output dir, env profiles
```

Suites import an aggregator and use `Suite Setup` / `Suite Teardown` from `browser_setup` /
`api_setup`. Page and component resources are added to `resources/pages.resource` as they are created;
API service resources to `resources/api.resource`.

## Conventions

- Run everything through `uv run` so it uses the locked environment.
- Never commit secrets — keep them in `.env` and reference as `%{VAR}` in tests.
- Selectors live in `*** Variables ***`; keywords model multi-step domain tasks; no `Sleep`
  (use Browser/Robot waiting).
- Personal RobotCode overrides go in a gitignored `.robot.toml`.

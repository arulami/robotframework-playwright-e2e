# robotframework-playwright-e2e

Robot Framework E2E test suite. **Browser** library (Playwright-based) for UI, **RequestsLibrary** for API. Managed with `uv`; configured and run via RobotCode (`robot.toml`).

> Authoring conventions (selectors, assertions, waiting, resource/POM structure) auto-load from `.claude/rules/robotframework-scripting.md` and `.claude/rules/robotframework-architecture.md` when you touch test files. Don't restate them here.

## Running tests

Config (paths, output dir, env profiles, `BASE_URL`/`API_BASE_URL`/`HEADLESS`) lives in `robot.toml`. Secrets live in a gitignored `.env` (template: `.env.example`), loaded with `--env-file`.

```bash
# All suites, default profile (local → http://localhost:3000)
uv run --env-file .env robotcode run

# Headed, single suite
uv run --env-file .env robotcode run --variable HEADLESS:False tests/guest

# By tag
uv run --env-file .env robotcode run -i smoke
```

Results (`log.html`, `report.html`, `output.xml`) land in `results/` (gitignored). The app under test is expected at `http://localhost:3000` — start it before running.

## Layout

- `tests/<role>/` — suites per role (`guest`), plus `tests/api/` for API suites. Suites import an aggregator and use `Suite Setup`/`Suite Teardown` from `browser_setup`/`api_setup`.
- `resources/pages.resource` — single UI import surface; add page/component resources to it as they're created.
- `resources/api.resource` — single API import surface; add service resources to it as they're created.
- `resources/pages/`, `resources/components/`, `resources/api/` — page, component, and API service resources (created on demand).
- `resources/keywords/` — `browser_setup.resource` (browser lifecycle) and `api_setup.resource` (REST session).
- `libraries/` — Python helper keywords (created on demand).

## Conventions reminders

- Run everything through `uv run` so it uses the locked environment.
- Never put secrets in `robot.toml` (it's committed) — use `.env` and reference as `%{VAR}`. Personal config overrides go in a gitignored `.robot.toml`.
- Selectors as `*** Variables ***`, keywords as multi-step tasks, no `Sleep` — see the rules files above.

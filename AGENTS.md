# AGENTS.md — error-map

Error visualization application. Ingests error events from Datadog Logs API into PostgreSQL, normalizes request paths into stable route identities, and tracks payload field anomaly statistics.

GOAL: Create a visual heatmap of errors accross all routes, and match payloads to likelihood of errors.

---

## Stack

- **Ruby 4.0.5** (`.ruby-version`) · **Rails 8.1.3.1**
- **PostgreSQL** — single dev/test DB; production uses four separate DBs (primary, cache, queue, cable)
- **Solid Queue / Solid Cache / Solid Cable** — database-backed adapters (no Redis)
- **Faraday** — HTTP client for Datadog API calls
- **Hotwire** (Turbo + Stimulus) + **Propshaft** + Import Maps (no Node/npm build step)

---

## Commands

### Development

```bash
bin/setup          # bundle install + db:prepare + starts dev server
bin/dev            # start dev server via foreman (Procfile.dev)
bin/rails server   # alternative; sets RUBY_DEBUG_OPEN=true in dev
```

### Tests

```bash
bundle exec rspec                        # full suite
bundle exec rspec spec/models/route_spec.rb                 # single file
bundle exec rspec spec/models/route_spec.rb:42              # single example by line
bundle exec rspec --tag focus                               # focused examples
```

- `spec/rails_helper.rb` — Rails + Capybara wiring; require in specs that need the DB or request stack.
- `spec/spec_helper.rb` — pure-Ruby RSpec config; required automatically via `.rspec`.
- Specs run in **random order** (`config.order = :random`); use the printed seed to reproduce failures.
- Each example is wrapped in a **database transaction** that rolls back — no manual cleanup needed.
- System specs use Capybara + selenium-webdriver; screenshots of failures are uploaded as CI artifacts.

### Lint / Security

```bash
bin/rubocop                      # lint (rubocop-rails-omakase ruleset)
bin/rubocop -a                   # auto-correct safe offenses
bin/brakeman --no-pager          # static security analysis
bin/bundler-audit                # gem CVE audit
```

### Local CI (runs all checks in sequence)

```bash
bin/ci    # rubocop → bundler-audit → brakeman → rspec → db:seed:replant
```

### Database

```bash
bin/rails db:prepare             # create + migrate (idempotent)
bin/rails db:reset               # drop + create + migrate + seed
env RAILS_ENV=test bin/rails db:seed:replant   # re-seed test DB
```

---

## Generators

`config.generators` sets `g.test_framework :rspec`, so `rails generate model/controller/scaffold` produces files under `spec/`, not `test/`.

---

## Required Environment Variables

These are fetched with `ENV.fetch` (raises `KeyError` if missing):

| Variable | Where used |
|---|---|
| `DD_API_KEY` | `DatadogClient` — Datadog API key |
| `DD_APP_KEY` | `DatadogClient` — Datadog application key |
| `DD_SITE` | `DatadogClient` — defaults to `datadoghq.com` if unset |
| `ERROR_MAP_DATABASE_PASSWORD` | `config/database.yml` — production DB only |
| `RAILS_MAX_THREADS` | `config/database.yml` — connection pool size (default 5) |
| `DATABASE_URL` | CI only — overrides database.yml in GitHub Actions |

No `.env` file is committed. Set variables in your shell or credentials for production.

---

## Architecture

### Data flow

```
Datadog Logs API
      │  (polled every 5 min via config/recurring.yml)
      ▼
DatadogSyncJob        ← Solid Queue, queue: :sync_datadog
      │
      ├─► RouteNormalizer.find_or_create   → routes table
      ├─► ErrorEvent.find_or_create_by!    → error_events table
      └─► Payload.find_or_create_by!       → payloads table
                                              (body stored as JSONB)
```

### Key domain rules

- **Route identity** = `(path, http_method, service, environment)` — unique index enforces this.
- **Path normalization** (`RouteNormalizer`): numeric IDs and UUIDs in path segments are replaced with `:id`, so `/users/123` and `/users/456` map to the same `Route`. Query strings are stripped.
- **ErrorEvent deduplication**: keyed on `datadog_event_id` (unique index). `find_or_create_by!` is safe to retry.
- **Payload**: one per `ErrorEvent`; body is a JSONB column. `param_fingerprint` is reserved for future structural analysis.
- **PayloadFieldStat**: aggregated anomaly stats per `(route, field_path, anomaly_type)` — unique index. Populated separately (not yet wired to a job).

### Background jobs

- `DatadogSyncJob` is the only job. Scheduled in `config/recurring.yml` (production only).
- Solid Queue stores jobs in the primary PostgreSQL DB (`solid_queue` tables).
- Start the queue worker locally with `bin/jobs` or via `bin/dev` if added to `Procfile.dev`.

---

## Code Style

- **Rubocop ruleset**: `rubocop-rails-omakase` — inherits Basecamp/Rails house style. Overrides go in `.rubocop.yml`.
- Run `bin/rubocop -a` to auto-fix; CI runs `bin/rubocop -f github`.
- Ruby LSP (`ruby-lsp`) is in the dev bundle and auto-detects the omakase config for editor diagnostics.

---

## CI (GitHub Actions — `.github/workflows/ci.yml`)

Four parallel jobs on every PR and push to `main`:

| Job | Command |
|---|---|
| `scan_ruby` | `bin/brakeman` + `bin/bundler-audit` |
| `lint` | `bin/rubocop -f github` |
| `test` | `bundle exec rspec` (with PostgreSQL service) |
| `system-test` | `bin/rails db:test:prepare test:system` (screenshots uploaded on failure) |

CI sets `RAILS_ENV=test` and `DATABASE_URL=postgres://postgres:postgres@localhost:5432`. The `test` environment enables eager loading only when `ENV["CI"]` is present.

Dependabot updates Bundler and GitHub Actions dependencies weekly.

---

## Gotchas

- **No Node/npm**: assets are served via Propshaft + Import Maps. Do not introduce a Node build pipeline.
- **Production uses 4 PostgreSQL databases** (primary, cache, queue, cable) but dev/test use a single DB — schema changes that affect Solid Queue/Cache/Cable tables live in separate migration paths (`db/queue_migrate`, etc.).
- **`test/` directory still exists** as a Rails scaffold artifact with `.keep` files only — ignore it; all real specs live in `spec/`.
- **`config/recurring.yml`** only schedules jobs in `production`. `DatadogSyncJob` must be enqueued manually in dev/test.
- **`DatadogClient` uses `ENV.fetch`** (not `ENV[]`) — it will raise immediately if `DD_API_KEY` or `DD_APP_KEY` are not set, even in tests. Stub or mock `DatadogClient` in specs that don't need real API calls.
- **Gems not installed for Ruby 4.0.5**: if `bundle exec` fails with `GemNotFound`, run `bundle install` first.

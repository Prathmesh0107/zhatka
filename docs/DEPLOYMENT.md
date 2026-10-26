# Ruchira POS: deployment, migration and release guide

> **Status of this guide.** Source code was changed and unit-tested in a sandbox with no network, no PostgreSQL, no Supabase and no
> Render. Nothing below has been run against your real services. Steps marked **YOU** must be done by an operator.
> See `docs/TEST_REPORT.md` for what was and was not executed.

## 1. Environment variables (Render → Environment)

| Variable | Required | Value / meaning |
|---|---|---|
| `DATABASE_URL` | yes | Supabase **Session Pooler** string. Ideally a least-privilege role (section 6). Never commit it. |
| `APP_ENV` | recommended | `production` (default if unset). Only `development`/`dev`/`local`/`test` relax anything. |
| `ADMIN_PASSWORD` | **first start of an EMPTY database only** | 10 to 128 chars, not a common password. With no users and no `ADMIN_PASSWORD` the app **refuses to start**. Remove it afterwards. |
| `ADMIN_USERNAME` | optional (same time) | Default `admin`. 3 to 32 chars `a-z 0-9 . _ -`. |
| `TRUSTED_PROXY_HOPS` | recommended | Proxies you control in front of the app. **Render = 1** (default). Use `0` if nothing is in front. |
| `CSP_MODE` | optional | `report-only` (default): a compatible policy is enforced, a strict one is only reported in the browser console. `enforce`: strict policy enforced. `baseline`, `off`. |
| `SEED_DEMO_DATA` | optional | Default `false`. Even `true` is **ignored when `APP_ENV=production`**. Controls demo menu and `/api/demo/reset`. |
| `SEED_DEMO_ORDERS` | optional | Default `false`. Only with demo data enabled. |
| `SEED_RUCHIRA_MENU` | optional | Default `false`. `true` once, on an EMPTY database for Ruchira, to load the Marathi menu. Never set for another restaurant. |
| `AUTH_SCHEMA` | optional | `public` (default) or `private` after optional migration 0004. |
| `AUTH_REQUIRED` | do not set | `false` disables login. **Ignored in production.** |
| `ENABLE_DOCS`, `CORS_ORIGINS` | optional | As before. |
| `SKIP_SCHEMA_CHECK` | emergency | `true` lets the app start with an incomplete schema (it logs the problems). |
| `MAX_BODY_BYTES` | optional | Default 262144. Requests that declare a bigger body get 413. |

**Build command:** `pip install -r backend/requirements.txt`
**Start command:** `uvicorn backend.app:app --host 0.0.0.0 --port $PORT`
Inside `backend/` the equivalent is `uvicorn app:app` (both import styles are supported). Keep **one worker** unless you accept that
the login limiter and session cache are per process (section 7).
*Whether your Render service currently uses these commands was not inspected: check Settings → Build & Deploy.*

## 2. First deployment on a NEW database (new client instance)
1. Create a Supabase project. Use a **separate project (or at least separate database and credentials) per client**.
2. SQL editor: run `migrations/0001_baseline_schema.sql`, `0002_security_hardening.sql`, `0003_order_integrity.sql` in that order.
3. Render env: `DATABASE_URL`, `ADMIN_USERNAME`, `ADMIN_PASSWORD` (strong, unique per client), `APP_ENV=production`.
4. Deploy. Sign in, open **Main Menu → Change password** if you want a different one, then **delete `ADMIN_PASSWORD`** from Render.
5. Settings → Logins: add staff. Each staff login gets a **temporary** password and must choose their own at first sign-in (the server refuses everything else until then).

## 3. Upgrading the EXISTING live instance (Ruchira)
Do these in order, in a quiet period. Nothing here is automatic.
1. **Backup checklist** (section 4). Save the row counts (`verification_after_migration.sql`, query E).
2. Run, in the SQL editor, the read-only files in `migrations/diagnostics/` (01 to 06) and read the results. Fix anything they flag (duplicate order numbers, rows that would violate the new checks).
3. Run `0002_security_hardening.sql`, then `0003_order_integrity.sql` (0001 is only needed if diagnostics show missing pieces).
4. Run `migrations/verification_after_migration.sql` and compare with expectations written in the file.
5. Deploy the new code. At startup the app **only reads** the schema. Existing users are untouched. A login that still accepts the old default password is **flagged**, not deleted: it must change the password at next sign-in (check the server log for the line "still use a well-known default password").
6. **Rotate credentials** (section 5), sign in as owner, confirm: menu, orders, reports, a test order, print.
7. Browser: leave `CSP_MODE=report-only` for a few days, open the app on a phone and a PC, check the browser console for `Content-Security-Policy-Report-Only` messages (there should be none). Then set `CSP_MODE=enforce`.

## 4. Backup checklist (before any migration)
- Supabase → Database → Backups: confirm a recent backup exists, or take a manual one (paid plans). On the free plan export instead:
  `pg_dump "<DATABASE_URL>" --no-owner -Fc -f ruchira_$(date +%F).dump` from your own computer, store it **off** the server.
- Also export CSVs of `orders`, `order_items`, `menu_items`, `categories`, `inventory_purchases`, `users`, `settings` (Table editor → Export).
- Record row counts of all tables. Test that the dump restores into a **scratch** database (`pg_restore`).
- Do not paste the dump, the URL or passwords into chat, tickets or git.

## 5. Credential rotation (separately, by you)
- The old `admin/admin123` document was publicly downloadable from `/static/README.txt`. Treat the old default password as **burned** on every instance that ever served it, even if you changed it later: confirm each owner password is unique and strong, and that no login still uses `admin123` (the app now flags and forces a change).
- Rotate `DATABASE_URL` password in Supabase (Database → Settings → Reset password), update Render, restart. Existing sessions stay valid; to force everyone to sign in again run `delete from public.sessions;`.
- Rotate any other secret that was in `.env` copies or git history. If the repo ever contained `.env` or a URL, rotate that password.

## 6. Least-privilege database role (recommended, optional)
The app connects with `DATABASE_URL`. If that is the `postgres` role it can do everything and **bypasses row level security**, so RLS does not protect against the app's own connection, only against the public API key. `migrations/0005_OPTIONAL_least_privilege_role.sql` is a template for a role that can only read/write the app tables. Create it with the password typed only into the SQL editor, switch Render to the new URL, verify, and keep the old URL until sure. Because the app no longer runs DDL, this role needs no DDL rights.

## 7. Limits you should know
- **Login limiter** is in memory, per process. With N workers/instances the effective limit is N times higher and counters reset on restart. It keys on client address (and username+address), so a stranger cannot lock the owner out; username-only locking was removed. It trusts exactly `TRUSTED_PROXY_HOPS` proxies. Add a Cloudflare/Render-level rate limit for more.
- **Request size**: only the `Content-Length` header is checked; field lengths are also bounded by validation.
- **One instance per client**: there is no tenant model (one `settings` row, no tenant column). Never put two businesses in one database. Isolate with: a separate Supabase project/DB, separate `DATABASE_URL` (ideally separate DB role), a separate owner password, separate Render service and env secrets. A shared database would let any owner/staff of one business read another's orders, customers and credentials.
- Sessions last 30 days; changing/resetting a password signs that user out elsewhere.

## 8. Roles (enforced on the server; the screen hiding buttons is only cosmetic)
Owner: everything. Staff may: view menu, categories, settings; create orders; view, edit and change the status of orders; print; switch a dish on/off (not name, category or price); change their own password.
Staff may NOT: delete orders or clear orders, change prices or the menu structure, see reports or inventory, change settings, manage logins, run the demo reset, test the server printer.
The table lives in `backend/core.py` (`STAFF_ALLOWED`); any route not listed there is owner-only by default.

## 9. Breaking changes
- Inventory and Reports are owner-only (staff used to see them). Staff delete-order is gone. Relax in `core.STAFF_ALLOWED` if the business needs it.
- New logins and password resets by the owner create **temporary** passwords (forced change). Minimum password length is now 10.
- No default account; empty database needs `ADMIN_PASSWORD`. `AUTH_REQUIRED=false` and `SEED_DEMO_DATA=true` are ignored in production.
- The app no longer creates/alters tables: apply `migrations/`. It refuses to start if required tables/columns are missing.
- The order number sent by the screen is only a hint; the server assigns the real number. If two devices collide the existing "saved as #N" alert appears.
- Starter categories (Pizza, Burgers...) are no longer re-created on every restart. The Ruchira menu is only loaded when `SEED_RUCHIRA_MENU=true`.
- `/api/orders` and `/api/inventory` return at most `limit` (default 1000, max 5000) rows. `/static` serves only js/css/images/fonts. `README.txt`, the root `app.js` and `backend/_check_settings.py` were removed.
- Validation: `order_type` must be Pickup or Delivery (any case); text fields have length limits; 422 replaces 200 for invalid data.

## 10. Release checklist
- [ ] Backup taken, restore tested on a scratch DB, row counts saved
- [ ] Diagnostics 01 to 06 reviewed; duplicates / violating rows resolved
- [ ] Migrations 0002 and 0003 applied; `verification_after_migration.sql` as expected
- [ ] Decide on optional 0004 (private schema) and 0005 (least-privilege role); each in its own window
- [ ] Render env set (`APP_ENV=production`, `TRUSTED_PROXY_HOPS=1`, no `AUTH_REQUIRED`, no `SEED_DEMO_DATA=true`, `ADMIN_PASSWORD` removed after first start)
- [ ] Build/start commands match section 1
- [ ] Deployed; startup log has no schema error; "default password" accounts handled
- [ ] Owner and staff test: login, forced change, order, status moves, print, reports (owner), staff blocked from reports/inventory/delete
- [ ] `/static/README.txt` and `/static/.env` return 404 on the live URL
- [ ] Phone + PC console shows no CSP report-only violations for several days, then `CSP_MODE=enforce`
- [ ] Credentials rotated (section 5); each client instance has its own DB, password and secrets
- [ ] Run `pytest` against a **local** test database (not production) and `node --test tests/frontend/test_actions.test.js`

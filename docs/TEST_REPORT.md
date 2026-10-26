# Test report

## Environment limits (why a lot was NOT run)
The sandbox had **no internet, no PostgreSQL, no Supabase, no Render, no browser**, and neither FastAPI, pydantic, psycopg nor pytest
installed (`pip install` failed: name resolution). Available: Python 3.12 (standard library), Node 22, Pillow. Therefore the API,
database and browser behaviour were **not exercised**. This is source-code testing only; no live deployment was verified.

## Commands run and results (all actually executed)
| Command | Result |
|---|---|
| `python3 -m unittest discover -s tests -p "test_core.py" -v` | **40 tests, OK** (order types, money, totals, IST/UTC boundaries, client-IP spoofing, login limiter, permission matrix, password policy, static allow-list, headers) |
| `node --test tests/frontend/test_actions.test.js` | **9 tests, 9 pass** (esc/jsArg safety, hostile names stay one inert argument, bad payloads rejected before any call runs, every real `data-on*` handler in app.js parses and is registered, no inline handlers or scripts left) |
| `node --check` on app.js, actions.js, bluetooth.js | OK |
| `python3 -m py_compile` on backend/app.py, core.py, run.py, all tests | OK |
| AST undefined-name check on backend/app.py | no real issues (2 closure false positives) |
| import of backend/app.py against minimal stubs of fastapi/pydantic/psycopg | imports; 21 route registrations carry the OWNER dependency |
| grep for credentials | only the deliberate denylist in core.py and warnings in docs |

One real bug was found and fixed by these tests: the dispatcher ran the first call of `nav('x');alert(1)` before rejecting the second. It now validates every call before running any.

## Written but NOT run (need `pip install -r requirements-dev.txt` and a disposable PostgreSQL in `TEST_DATABASE_URL`)
`tests/test_api_security.py` (default account gone, bootstrap refusal, flagged legacy account, forced password change on 8 routes, staff 403 on 20 owner routes, staff dish toggle vs price change, kitchen workflow, route-vs-matrix, static 404s, headers, logout/expired/invalid session, limiter over HTTP, validation errors don't echo passwords) and
`tests/test_api_orders.py` (order-type allow-list create+update, negative/invalid fee, Marathi text, 12 concurrent orders, client number not trusted, duplicate submit, DB unique number, rollback after failed item insert, pagination, India month boundaries through `/api/reports`, generic errors, demo reset off).
They could contain mistakes that only a real run will show.

## Not tested at all
SQL migrations (syntax and effect), live Supabase grants/RLS, Render build/start, `pip install` from a clean environment, any browser behaviour (rendering, printing popups/iframe, Bluetooth, mobile), CSP behaviour, pydantic validator behaviour, real concurrency, performance.

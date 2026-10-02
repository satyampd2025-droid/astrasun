# Atulyaa mill system: architecture (HLD) and low-level design (LLD)

## Part 1. High-level design (HLD)

### Idea in one line
ERPNext is the single book of record (stock, sales, money). Our own small app `astrasun` adds the mill rules on top. The phone app is a thin screen that only talks to that server.

### Boxes and arrows
```
 PHONE APP (Flutter, Android)                 BROWSER (ERPNext desk, for owner/accounts)
  Hindi/English, big buttons, voice                          |
  one home screen per role                                   |
          |  HTTPS, login cookie, JSON                       |
          v                                                  v
 +---------------------------------------------------------------------+
 |  nginx (frontend)  -> routes /api to backend, /socket.io to websocket|
 +---------------------------------------------------------------------+
        |                                  |
 +--------------+   +------------------------------------------------+
 | websocket    |   | backend (gunicorn)  = Frappe + ERPNext         |
 | live updates |   |   + India Compliance (GST, e-invoice, e-way)   |
 +--------------+   |   + astrasun (our mill rules and phone API)    |
                    +------------------------------------------------+
        |                    |                       |
 +--------------+   +----------------+     +-----------------------+
 | Redis cache  |   | Redis queue    |     | MariaDB (all records) |
 +--------------+   +----------------+     +-----------------------+
                         ^
        queue workers + scheduler (background jobs: invoices, alerts)
```
Everything above runs from one docker compose file (`docker/compose.prod.yml`) on one server.

### Who owns what
| Layer | Owns | Does not own |
|---|---|---|
| ERPNext | Customers, items, prices, stock ledger, invoices, payments, GST, e-way bill, accounts, P&L | Mill-specific rules |
| `astrasun` app | Wheat lot, milling batch, downtime, loading task, approval rules, weight/moisture/yield checks, audit log, phone API | Accounting |
| Flutter app | Screens, language, voice input, role home | Any business rule (the server decides) |

### Key design rules
1. **One ledger.** Wheat in, flour out, bags sold and money received all hit the same ERPNext stock and account ledgers. That is how nothing goes untracked.
2. **Server enforces, phone only asks.** Credit limit, stock check, below-price approval, no self-approval, invoice before dispatch are all checked on the server. A modified phone app cannot skip them.
3. **Role = who sees what.** Each user has mill roles (Owner, Manager, Sales, Gate, QC, Production, Packing, Warehouse, Dispatch, Driver, Accounts, Auditor). The phone asks the server `me()` and shows only that role's buttons. The server also checks the role on every call.
4. **Critical changes need a reason** and are written to an append-only Critical Change Log.
5. **Don't rebuild ERPNext.** We never edit it; everything lives in our own app, so upgrades stay safe.

### Deployment
Now: demo data inside the app, plus a dockerised server for tests. Recommended for go-live: one EC2 t3.medium with docker compose (about $35 to $40 a month). EKS and CloudFormation files exist for a much later scale-up (`docs/AWS.md`).

## Part 2. Low-level design (LLD)

### 2.1 Repository layout
- `apps/astrasun/astrasun/` Python (server): `orders.py, loading.py, invoicing.py, delivery.py, payments.py, wheat.py, milling.py, packing.py, dashboard.py, reports.py, audit.py, api.py, hooks.py`
- `.../astrasun/doctype/` our own record types: `wheat_lot, milling_batch, machine_downtime, critical_change_log`
- `.../setup/` install scripts: roles, custom fields, masters (accounts, warehouses, bank)
- `.../tests/` 56 tests including the 15-step acceptance test
- `apps/mobile/lib/` Flutter: `api/` (client + demo client + models), `screens/`, `home/role_tasks.dart`, `strings.dart` (Hindi), `widgets/`
- `docker/` image and compose files, `infra/aws/` cloud files

### 2.2 Phone to server
- Phone calls `POST /api/method/astrasun.<module>.<function>` (a "whitelisted" Python function). Login uses Frappe's cookie session.
- Two interchangeable clients behind one interface: `ErpNextClient` (real server) and `DemoClient` (in-memory demo data). The demo is why the app works without a server.
- Errors from the server (for example "credit limit exceeded") come back as messages and are shown on screen.

### 2.3 Records and links (what points to what)
```
Wheat Lot --(accepted)--> Stock Entry / Purchase Receipt --> Raw wheat store
Milling Batch --(Repack Stock Entry)--> wheat out, flour/bran/waste in, cost by weight
Packing --> Stock Entry: bulk flour -> bagged SKUs
Sales Order (approval fields) --> Loading Task --> Delivery Note --> Sales Invoice (+e-way bill)
Sales Invoice --> Payment Entry (oldest invoice first)
Every critical edit --> Critical Change Log (who, when, old, new, reason)
```

### 2.3.1 Order state flow
`Draft -> Pending approval -> Approved -> Loading -> Loaded -> Invoiced -> Dispatched -> Delivered -> Paid`
Order rules: customer over credit limit or price below list needs the Owner; creator cannot approve their own order; stock must cover the quantity.
Dispatch is refused until an invoice exists, and for invoices above Rs 50,000 an e-way bill number is required.

### 2.4 Wheat and milling rules
- Gate in, weigh in, lab check, weigh out. Net weight = gross minus tare.
- Weight gap vs supplier slip above 0.5%, moisture above 14%, foreign matter above 2% are flagged (placeholders until you confirm real limits).
- Milling batch: extraction below 78% or loss above 2% is flagged; batch cost is split by weight across outputs.

### 2.5 Permissions detail
Warehouse and driver roles cannot read accounting documents. For their jobs the server briefly acts as Administrator inside `loading._as_system()` after its own role check, then restores the real user as owner. This keeps the audit trail honest while letting them finish their step.

### 2.6 Language and voice
`strings.dart` holds Hindi and English; the choice is saved per user and also applied to the ERPNext web screens. Text fields accept voice input.

### 2.7 Testing and delivery
- Server: 56 tests run against a real ERPNext in docker; `test_acceptance.py` runs the 15 steps from the PRD end to end.
- Phone: 38 widget tests.
- CI builds, tests and signs an APK on every phone-code push and publishes it as a release.

### 2.8 Known gaps
Buying side (purchase order, supplier invoice and payment), wheat-lot to flour-bag tracing, flour QC, production planning, delivery photo proof, returns and credit notes, WhatsApp sending, offline mode, and a real-server test of the phone app. Details in `plan/who-sees-what.md`.

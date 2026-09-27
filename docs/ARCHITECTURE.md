# Astrasun: Architecture Decisions

Rule: don't rebuild what a proven open-source system already does. Build only what is specific to a flour mill.

## Decisions

| # | Decision | Why |
|---|---|---|
| 1 | **Core: ERPNext (Frappe) + India Compliance app** | Accounts, credit limits, stock, manufacturing (wheat → aata/maida/sooji/chokar as by-products), GST, e-invoice and e-way bill come ready-made and free (GPL). |
| 2 | **Our code lives in a custom Frappe app `astrasun`** | Upgrade-safe: we never edit ERPNext itself. |
| 3 | **Floor-staff app: Flutter** | Runs well on cheap Android phones, works offline, one codebase. Talks to ERPNext over its REST API. |
| 4 | **Hosting: cloud VPS (Mumbai region) with `frappe_docker`** | Reachable from anywhere; the mobile app covers internet outages at the mill. |
| 5 | **WhatsApp: Meta WhatsApp Cloud API** | Alerts and the owner's evening summary. |

## What ERPNext gives us (don't build)
- Customers, suppliers, items, price lists.
- Purchase order → purchase receipt → purchase invoice.
- Sales order (credit-limit check) → delivery note → sales invoice → payment.
- Stock ledger, warehouses, batches, units of measure (kg / quintal / bag).
- BOM with by-products, work orders, stock entries (manufacture).
- Quality Inspection (lab checks on wheat and flour).
- GST invoices, e-invoice, e-way bill, GSTR reports (India Compliance).
- Roles, permissions, approval workflows, Hindi translation, REST API.

## What we build (`astrasun` app)
- **Gate Entry**: truck, driver, party, purpose (wheat in / flour out).
- **Weighbridge Slip**: gross, tare, net; party weight vs mill weight → mismatch alert.
  Idea from [vj-mazu/stocks](https://github.com/vj-mazu/stocks) (two weighbridge readings).
- **Loading Task**: "load X bags on truck Y", done by loader, linked to delivery note.
- **Delivery Proof**: driver photo, cash collected, linked to payment.
- **Shift Production Log**: output per shift → extraction %, downtime.
- **Alerts engine**: rules from the PRD → app push + WhatsApp.
- **Insights**: cost per ton, profit per product, dues ageing, unusual activity.

Gate → weighbridge → lab → unload flow inspired by [Gourav1195/millsaathi](https://github.com/Gourav1195/millsaathi).

## Build order
1. ERPNext + India Compliance running locally in Docker; mill master data (items, BOM, warehouses, roles).
2. Gate Entry + Weighbridge Slip + mismatch alert.
3. Sales order with credit approval → loading task → dispatch.
4. Flutter app: login, role home screen, loading tasks, offline sync.
5. WhatsApp alerts + evening summary.
6. Owner dashboard and insights.
7. Deploy to VPS; pilot alongside registers.

## Working model
- Owner/founder decides priorities, how the mill works, and yes/no calls.
- Claude writes the code and tests and shows a demo for each step.

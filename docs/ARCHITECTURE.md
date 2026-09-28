# Astrasun: Architecture Decisions

Rule: don't rebuild what a proven open-source system already does. Build only what is specific to a flour mill.

## Decisions

| # | Decision | Why |
|---|---|---|
| 1 | **Core: ERPNext (Frappe) + India Compliance app** | Accounts, credit limits, stock, manufacturing (wheat → aata/maida/sooji/chokar as by-products), GST, e-invoice and e-way bill come ready-made and free (GPL). |
| 2 | **Our code lives in a custom Frappe app `astrasun`** | Upgrade-safe: we never edit ERPNext itself. |
| 3 | **Floor-staff app: Flutter** | Runs well on cheap Android phones, works offline, one codebase. Talks to ERPNext over its REST API. |
| 4 | **Hosting: cloud VPS (Mumbai region) with `frappe_docker`** | Reachable from anywhere; the mobile app covers internet outages at the mill. |
| 5 | **WhatsApp: Meta WhatsApp Cloud API** (MVP) | Alerts, the owner's evening summary, and invoices/receipts to customers. |
| 6 | **ERPNext is the accounting system** | One ledger for stock, sales and money; P&L and balance sheet come straight from it. No Tally books. |
| 7 | **Hindi + English, voice input** (MVP) | Frappe translations for web; Flutter localisation and speech-to-text for the app. |

Full decision log and PRD amendments: [DECISIONS.md](DECISIONS.md).

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

## Build order (matches PRD delivery stages)
1. **Foundation:** ERPNext + India Compliance in Docker; roles, audit ("reason" on critical changes), masters (items/SKUs, BOMs, warehouses: raw wheat, bulk atta, finished goods, packaging, by-products).
2. **Inventory:** Gate Entry, Weighbridge Slip (weight gap), wheat lots with landed cost, QC with hold.
3. **Manufacturing:** shift production batch (tempering water, weight balance, yield), packing batch, traceability.
4. **Commercial:** sales order, minimum price engine, credit check, approval workflow (no self-approval).
5. **Fulfilment:** loading queue, invoice + e-invoice + e-way bill, dispatch, payment collection.
6. **Mobile + messaging:** Flutter app for each role (Hindi/English, voice), WhatsApp alerts and receipts.
7. **Management:** owner dashboard, Six Sigma KPIs, stock statement, P&L, exports.
8. **UAT & go-live:** deploy to VPS, backup/restore test, pilot alongside registers.

## Working model
- Owner/founder decides priorities, how the mill works, and yes/no calls.
- Claude writes the code and tests and shows a demo for each step.

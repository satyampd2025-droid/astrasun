# Decision Log and PRD Amendments

The main requirements are in [Atulyaa_Mill_MVP_PRD_v1.0.docx](Atulyaa_Mill_MVP_PRD_v1.0.docx) ("the PRD").
This file records the decisions made since, and where they change the PRD.
The older short [PRD.md](PRD.md) is kept for background only; where they differ, the PRD and this log win.

## Decisions

| # | Date | Decision | Effect on the PRD |
|---|---|---|---|
| D1 | 2026-09-27 | Core platform is **ERPNext (Frappe) + India Compliance**, with our own `astrasun` Frappe app. | Point 6 architecture is implemented on ERPNext. See [ARCHITECTURE.md](ARCHITECTURE.md). |
| D2 | 2026-09-27 | Floor-staff app is **Flutter**. | Point 31: mobile-first screens are built in Flutter; office/admin work uses ERPNext web. |
| D3 | 2026-09-27 | Hosting on a **cloud VPS** (Mumbai region) with `frappe_docker`. | Point 30: backups and restore run on the VPS. |
| D4 | 2026-09-28 | **ERPNext is the accounting system.** No separate Tally books. | Points 20, 25, 26: P&L and balance sheet come from ERPNext's own ledger, so there is no reconciliation with another system. The CA gets exports or read-only access. |
| D5 | 2026-09-28 | **Invoice (with e-invoice IRN and e-way bill) is created before the truck leaves.** | Point 14 order status becomes: DRAFT → SUBMITTED → PENDING APPROVAL → APPROVED → WAREHOUSE NOTIFIED → LOADING → LOADED → **INVOICED → DISPATCHED** → DELIVERED. MVP acceptance steps 9 and 10 swap. |
| D6 | 2026-09-28 | **Hindi, voice input and WhatsApp are in the MVP.** | Point 31 adds Hindi/English on every screen and voice for remarks and reasons. Point 29 notifications go to app push and WhatsApp, including the owner's evening summary and customer invoice/receipt messages. |

## Scope added to the MVP (gaps found in the PRD)

| Gap | Addition |
|---|---|
| No step for recording customer payments, though receivables must update (acceptance step 11). | Payment collection: customer, amount, mode (cash/UPI/cheque/NEFT), reference, photo proof; auto-matched to oldest invoices; cash collected on the road is confirmed by accounts. |
| No supplier payment flow, though payables are reported. | Supplier payments through ERPNext's standard Payment Entry (web). |
| Returns/complaints KPI (Point 27) has no flow behind it. | Sales return with credit note through ERPNext (web). |
| Tempering water would show as false loss in the weight balance (Point 10). | Production batch records water added; the balance is (wheat + water) in vs outputs out. |
| GST may differ by pack size (≤25 kg vs 26/50 kg). | Tax template per SKU; rates to be confirmed with the CA. |
| Minimum price engine inputs are underspecified (Point 16). | To be fixed in the workshop: wheat cost basis (daily market price or actual lot cost) and the monthly volume used to allocate fixed costs. |

## Still open

- **Offline use.** The PRD puts it after the MVP. If needed earlier, gate, loading and packing screens will save on the phone and sync later.
- **Timeline** for Stages 0–7.
- Workshop questions from PRD section 44, plus: weighbridge make/model, daily capacity and shifts, number of staff with smartphones, WhatsApp Business number to use.

## Design

Phone-screen journeys for the MVP: [design/journeys.html](design/journeys.html).

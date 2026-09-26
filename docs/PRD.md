# PRD: Astrasun, the Aata Mill Operating App

| | |
|---|---|
| **Status** | Draft v0.1 |
| **Owner** | Mill Owner / Founder |
| **Last updated** | 2026-09-26 |
| **Audience** | Owner, management, developers, designers, and pilot users |

---

## 1. Summary

Astrasun is a mobile-first app that runs the day-to-day operations of an aata (wheat flour) mill. It covers the full chain: buying wheat, receiving it at the gate, weighing, quality checks, milling, packing, stock, sales orders, loading, dispatch, billing, and payment collection.

Everyone in the company uses it, from the owner to the loading staff. Each person sees only what they need, can record their work in a few taps (or by voice, in their own language), and gets notified when something needs their attention. Because every step is recorded in one place, the app can also give **intelligent insights**: yield and extraction trends, losses, margin per product, customer payment risk, demand forecasts, and alerts on anything unusual.

## 2. Problem statement

Today, a typical aata mill runs on a mix of paper registers, WhatsApp messages, phone calls, and an accounting package that is updated late. The results:

- **No single source of truth.** Wheat received, flour produced, bags packed, and bags dispatched are recorded in different places by different people, so they rarely reconcile.
- **Information delays.** The owner learns about a problem (low stock, a truck waiting, a customer over their credit limit, a machine down) hours or days late.
- **Hidden losses.** Weight differences at the weighbridge, excess moisture in wheat, low extraction, bag shortages, and unbilled dispatches go unnoticed.
- **Unstructured decisions.** Wheat buying, pricing, and production planning rely on gut feel instead of the mill's own historical data.
- **Staff coordination is manual.** Loading staff wait for instructions, sales reps call the office to check stock, and accounts chases dispatch for delivery details.

## 3. Goals and non-goals

### Goals
1. **Seamless process.** Every operational step is captured once, at the source, by the person doing it, in 30 seconds or less.
2. **Everyone informed.** Each role gets the right notifications and a role-specific home screen, so nobody has to call anyone to ask "what's the status?"
3. **Intelligent insights.** Turn operational data into daily summaries, KPIs, anomaly alerts, and recommendations the owner can act on.
4. **Reconciliation by default.** Wheat in, product out, stock, dispatch, and billing reconcile automatically, and mismatches are flagged.
5. **Works for the real mill floor.** Hindi, English, and regional language support, large touch targets, voice input, and offline mode for low connectivity.

### Non-goals (v1)
- Replacing a full statutory accounting system (Tally or similar). v1 **integrates with or exports to** it.
- Automated machine control (PLC/SCADA). v1 reads machine data where available but doesn't control machines.
- A consumer (B2C) e-commerce storefront.
- Payroll and HR beyond attendance and shift assignment.

## 4. Users and roles

| Role | Who | Primary needs in the app |
|---|---|---|
| **Owner / Director** | Founder, partners | Live dashboard, daily summary, profit and loss by product, alerts, approvals (credit, price, large purchases), AI insights |
| **Plant / General Manager** | Runs daily ops | Production plan, shift status, stock, pending dispatches, staff tasks, exceptions |
| **Procurement / Purchase** | Buys wheat | Supplier (farmer/mandi/broker) list, purchase orders, rates, incoming truck tracking, quality-based rate deductions |
| **Gate / Security** | Gate staff | Vehicle entry/exit log, linking vehicles to purchase or sales orders, photos |
| **Weighbridge Operator** | Weighbridge | Gross/tare capture (manual or from weighbridge integration), weighment slip |
| **Quality / Lab** | Lab technician | Wheat sampling (moisture, gluten, foreign matter, broken grain), flour QC (ash, moisture, granulation), accept/reject/deduct |
| **Production / Mill Operator** | Shift in-charge | Start/stop batch, wheat input to mill, output by product (aata, maida, sooji, chokar/bran), downtime reasons, power readings |
| **Packing** | Packing supervisor | Bags packed by product and size (1/5/10/25/50 kg), batch/lot number, packing material usage |
| **Store / Warehouse** | Storekeeper | Raw material (silo) stock, finished-goods stock by SKU, packing material, spares, stock transfers |
| **Sales Representative** | Field sales | Customer list, take orders, check live stock and price, credit status, outstanding, visit log |
| **Dispatch / Logistics** | Dispatch in-charge | Assign orders to vehicles, loading slips, driver details, e-way bill, delivery tracking |
| **Loading Staff** | Loaders | Simple list: "Load truck X with N bags of SKU Y", tap to confirm count, flag shortage/damage |
| **Driver** | Own or hired drivers | Trip details, delivery confirmation (photo + signature/OTP), cash collected |
| **Accounts** | Accountant | Invoices (GST), payments received, receivables aging, supplier payments, Tally export |
| **Maintenance** | Fitter / electrician | Breakdown tickets, preventive maintenance schedule, spare parts used |

**Permissions:** Role-based access control (RBAC). The owner can create custom roles and grant granular permissions (view/create/edit/approve per module). Sensitive data (margins, rates, profit) is visible only to permitted roles.

## 5. End-to-end process flow

```
 PROCUREMENT                RECEIVING                     STORAGE
 ┌──────────────┐   ┌──────────────────────────────┐   ┌──────────┐
 │ Purchase     │──▶│ Gate entry → Weighbridge     │──▶│ Silo /   │
 │ order (rate, │   │ (gross) → QC sample →        │   │ godown   │
 │ qty, party)  │   │ Unload → Weighbridge (tare)  │   │ stock    │
 └──────────────┘   │ → Net weight, deductions     │   └────┬─────┘
                    └──────────────────────────────┘        │
 PRODUCTION                                                  ▼
 ┌─────────────────────────────────────────────────────────────────┐
 │ Cleaning → Tempering/conditioning → Milling →                   │
 │ Outputs: Aata / Maida / Sooji / Chokar (bran) + process loss    │
 └───────────────────────────────┬─────────────────────────────────┘
                                 ▼
 PACKING & FG STOCK        SALES                 DISPATCH & BILLING
 ┌────────────────┐   ┌──────────────────┐   ┌──────────────────────────┐
 │ Bags by SKU,   │──▶│ Sales order      │──▶│ Vehicle assign → Loading │
 │ lot no., label │   │ (rep/office),    │   │ → Weighbridge → Invoice  │
 │                │   │ credit check,    │   │ + e-way bill → Gate out  │
 └────────────────┘   │ approval         │   │ → Delivery proof → Payment│
                      └──────────────────┘   └──────────────────────────┘
```

Every arrow is a **status change** that triggers notifications to the next person in the chain.

## 6. Functional requirements

Priority: **P0** = MVP must-have, **P1** = shortly after MVP, **P2** = later.

### 6.1 Masters and setup (P0)
- Products/SKUs: product type, pack size, MRP, base price, HSN, GST rate.
- Parties: suppliers (farmers, mandis, brokers), customers (distributors, retailers, bulk buyers, institutions) with GSTIN, credit limit, payment terms, and assigned sales rep.
- Vehicles, drivers, silos/godowns, machines, and users/roles.
- Wheat quality parameters and the deduction matrix (e.g., rate deduction per % moisture above 12%).

### 6.2 Procurement (P0)
- Create a purchase order or a spot purchase with supplier, variety, quantity, and rate.
- Track incoming trucks against purchase orders.
- Auto-calculate the payable amount from net weight, quality deductions, bardana (bags), and mandi/brokerage charges.
- Supplier ledger and payment status.
- **P1:** Daily mandi rate capture (manual or feed), and rate history charts by variety and region.

### 6.3 Gate and weighbridge (P0)
- Gate entry: vehicle number (with number-plate photo), purpose (inward/outward), linked order, driver phone.
- Weighbridge: gross and tare capture; **P1:** direct integration with the weighbridge indicator (serial/USB/IoT) to remove manual entry.
- Weighment slip generation (print/PDF/WhatsApp share).
- **Alert** when the net weight differs from the supplier's bill or the loading slip beyond a set tolerance.
- Vehicle turnaround time tracking (gate-in to gate-out).

### 6.4 Quality control (P0)
- Record wheat sample results: moisture, foreign matter, broken/shrivelled grain, gluten, hectolitre weight, plus a photo.
- Accept, reject, or accept with deduction. Rejection notifies procurement and the owner.
- Flour QC per batch: moisture, ash, granulation, water absorption (as the lab supports).
- **P1:** Lot traceability, from a finished bag's lot number back to the wheat lots and supplier used.

### 6.5 Production (P0)
- Daily/shift production plan (from the manager, based on orders and stock).
- Batch/shift log: wheat issued to the mill, output of each product, and process loss.
- **Automatic extraction/yield calculation** (e.g., aata % of wheat input) per batch, shift, and day.
- Downtime log with reason codes (power cut, breakdown, no wheat, cleaning).
- Power meter readings (units consumed) → power cost per ton.
- **P2:** Machine sensor/IoT integration (motor current, running hours, silo levels).

### 6.6 Packing and inventory (P0)
- Record bags packed by SKU with lot number and packing date; **P1:** barcode/QR labels.
- Live stock for wheat (by silo/lot), finished goods (by SKU), packing material, and spares.
- Stock movements are automatic from receipts, production, packing, and dispatch; manual adjustments need a reason and approval.
- Reorder alerts (wheat below N days of cover, bags/packing film low).
- Periodic physical stock count with variance report.

### 6.7 Sales (P0)
- Sales reps create orders in the field (works offline, syncs later).
- Live view of stock availability and the customer's price list.
- **Credit check:** an order over the credit limit or with overdue invoices needs owner/manager approval (one-tap approve/reject from a notification).
- Order statuses: Draft → Approved → Planned → Loading → Dispatched → Delivered → Paid.
- Customer view for the rep: outstanding, last orders, and payment history.
- **P1:** Scheme/discount management, beat/route planning, visit check-in with GPS.
- **P2:** Customer/distributor self-ordering portal or WhatsApp ordering bot.

### 6.8 Dispatch and loading (P0)
- Dispatch planner: group orders into a vehicle trip based on capacity and route.
- **Loading task** sent to loading staff: vehicle number, SKU, number of bags, dock/godown. Loaders tap "Loaded" with the count; shortages and damage are flagged with a photo.
- Outward weighbridge check against the expected load weight.
- Invoice and e-way bill generation (**P1:** e-invoice/e-way bill API integration).
- Driver app/link: trip details, delivery confirmation with photo and OTP/signature, cash/UPI collected.
- Customer notified by WhatsApp/SMS at dispatch and delivery.

### 6.9 Accounts and payments (P0)
- GST-compliant sales invoices and credit/debit notes.
- Payment receipts (cash, UPI, bank, cheque) linked to invoices.
- Receivables aging (0–15, 16–30, 31–60, 60+ days) by customer and sales rep.
- Supplier payables.
- Export to Tally (XML/Excel) in P0, **P1:** two-way sync.
- **P1:** Payment reminders to customers (WhatsApp) with a UPI payment link.

### 6.10 Maintenance (P1)
- Breakdown tickets raised by operators (photo + voice note), assigned to maintenance, with time-to-fix tracking.
- Preventive maintenance schedule per machine (e.g., roll changes, sieve cleaning) with reminders.
- Spare-parts consumption linked to store stock.

### 6.11 Tasks, attendance, and communication (P0/P1)
- **P0:** Task assignment with due time and status. Every workflow step generates tasks automatically (e.g., "QC sample pending for truck MH12AB1234").
- **P0:** An activity feed per order, truck, and batch, with comments, photos, and @mentions, so conversations stay attached to the work instead of scattered across WhatsApp.
- **P1:** Shift attendance (selfie + geofence) and shift assignment.
- **P1:** Announcements from the owner/manager to all staff or to specific roles.

## 7. Notifications: keeping everyone informed

Notifications are **role-aware**, **actionable** (approve/confirm directly from the notification), and delivered through **in-app push + WhatsApp**, with SMS as a fallback. Every user can set quiet hours; critical alerts override them.

| Event | Who is notified | Channel |
|---|---|---|
| Wheat truck arrived at gate | Procurement, weighbridge, QC | Push |
| QC rejected / heavy deduction | Procurement, owner | Push + WhatsApp |
| Weight mismatch beyond tolerance | Manager, owner | Push + WhatsApp (critical) |
| Order needs credit approval | Owner / manager | Push with Approve/Reject |
| Order approved | Sales rep, dispatch | Push |
| Loading task assigned | Loading staff | Push (large, audio alert) |
| Loading shortage/damage | Dispatch, store, manager | Push |
| Vehicle dispatched | Sales rep, accounts, customer | Push; customer via WhatsApp/SMS |
| Delivered / payment collected | Sales rep, accounts | Push |
| Invoice overdue | Sales rep, accounts; owner if 60+ days | Push + weekly digest |
| Stock below reorder level | Store, procurement, manager | Push |
| Machine breakdown | Maintenance, production, manager | Push (critical) |
| Extraction/yield below target | Production, manager | Push |
| **Daily summary (evening)** | Owner, manager | WhatsApp + in-app |
| **Daily briefing (morning)** | Each role, tailored | In-app |

**Example daily owner summary (WhatsApp):**
> Aaj ka summary (26 Sep): Wheat received 84 t (avg ₹2,480/q). Milled 72 t, aata extraction 74.8% (target 75%). Dispatched 3,120 bags, 11 trucks. Sales ₹18.6 L, collections ₹14.2 L. ⚠️ 2 alerts: Silo 3 moisture high; Sharma Traders ₹3.1 L overdue 45 days.

## 8. Intelligent insights (analytics and AI)

### 8.1 Dashboards (P0)
- **Owner dashboard:** today's and month-to-date sales, collections, production, extraction %, stock value, receivables, gross margin per product, and open alerts.
- **Manager dashboard:** shift performance, downtime, pending trucks, pending loading, and staff tasks.
- **Sales dashboard:** target vs. achievement per rep, top customers, and product mix.

### 8.2 Core KPIs (P0)
- Extraction/yield % per product, batch, shift, and wheat variety.
- Process loss % and moisture gain/loss.
- Power units per ton and cost per ton.
- Conversion cost per quintal (wheat + power + labour + packing + overheads) → **margin per SKU**.
- Vehicle turnaround time (inward and outward).
- Order-to-dispatch and dispatch-to-delivery time.
- Receivables days (DSO), collection efficiency.
- Stock days of cover (wheat and finished goods).

### 8.3 Smart alerts and anomaly detection (P1)
- Unusual weight differences, repeated shortages by the same loader or vehicle, or suppliers with a pattern of high moisture.
- Extraction dropping compared with the 7-day/30-day baseline (possible roll wear or settings issue).
- Power per ton spiking (possible machine issue).
- Customers whose payment behaviour is worsening (early warning before they go overdue).
- Stock mismatches between system and physical counts.

### 8.4 Predictive and recommendation features (P1/P2)
- **Demand forecast** per SKU and region (seasonality, festivals, past orders) → suggested production plan. (P1)
- **Wheat buying advisor:** how much wheat to buy based on forecast, current stock, and price trends; best-value suppliers based on quality-adjusted cost. (P2)
- **Price recommendation:** suggested selling price per SKU from wheat cost, conversion cost, and target margin. (P2)
- **Credit risk score** per customer. (P2)
- **Maintenance prediction** from downtime history and running hours. (P2)

### 8.5 Ask-the-app assistant (P1)
- A natural-language assistant (Hindi/English, text or voice) that answers questions over the mill's data, for example:
  - "Pichle hafte sabse zyada aata kis distributor ne liya?" (Which distributor bought the most aata last week?)
  - "Why was extraction low on Tuesday night shift?"
  - "Which customers have more than ₹1 lakh overdue?"
- Answers cite the underlying numbers and link to the relevant records.
- Respects the user's permissions (a sales rep can't see margins).
- Generates the daily and weekly summaries described in section 7.

## 9. UX principles

1. **Role-based home screen:** each user opens the app to "what I need to do now", not a menu.
2. **Minimum typing:** large buttons, pickers, defaults, barcode/QR scan, camera capture, and voice input.
3. **Languages:** Hindi and English at launch; regional languages (e.g., Punjabi, Marathi, Gujarati) configurable. Icons and colour cues for users with low literacy.
4. **Offline first:** floor and field users can keep working without network; data syncs automatically with conflict handling.
5. **Low-end Android support:** runs smoothly on phones with 2–3 GB RAM, Android 9+.
6. **Everything has a status and an owner:** users can always see where an order, truck, or batch is, and who is holding it.
7. **Shared devices:** a shared tablet at the weighbridge/loading dock with quick PIN-based user switching.

## 10. Non-functional requirements

| Area | Requirement |
|---|---|
| **Platforms** | Android app (primary), iOS app, web dashboard for the owner/office/accounts |
| **Performance** | Common screens load in under 2 s on 4G; notifications delivered within 10 s |
| **Availability** | 99.5% uptime for cloud services; offline mode covers outages |
| **Security** | OTP login, RBAC, encrypted data in transit and at rest, full audit log (who changed what, when), device binding for sensitive roles |
| **Data integrity** | No hard deletes of transactions; edits after approval require a reason and are logged |
| **Backup** | Daily automated backups, 30-day retention, exportable data |
| **Compliance** | GST invoicing, e-way bill, e-invoice (as turnover requires), Indian data-protection law (DPDP Act) |
| **Scalability** | Supports multiple mills/branches and 200+ users in the future without re-architecture |

## 11. Integrations

| Integration | Priority |
|---|---|
| WhatsApp Business API (notifications, summaries, customer updates) | P0 |
| SMS gateway (fallback) | P0 |
| Tally export (P0) → two-way sync (P1) | P0/P1 |
| Weighbridge indicator (serial/IoT) | P1 |
| GST e-invoice and e-way bill APIs | P1 |
| UPI payment links / payment gateway | P1 |
| Barcode/QR label printers | P1 |
| Energy meters and machine sensors (IoT) | P2 |
| GPS tracking of vehicles | P2 |

## 12. Data model (high level)

Core entities: `User`, `Role`, `Party` (supplier/customer), `Product/SKU`, `PurchaseOrder`, `VehicleVisit` (gate + weighments), `QCSample`, `WheatLot`, `Silo`, `ProductionBatch`, `BatchOutput`, `PackingEntry`, `FinishedLot`, `StockMovement`, `SalesOrder`, `DispatchTrip`, `LoadingTask`, `Invoice`, `Payment`, `MaintenanceTicket`, `Task`, `Notification`, `AuditLog`.

`StockMovement` is the single ledger for all inventory changes, so stock can always be recalculated and reconciled from transactions.

## 13. Success metrics

Measured three months after full rollout, against a baseline recorded before launch:

| Metric | Target |
|---|---|
| Staff actively using the app weekly | ≥ 90% of all staff |
| Transactions captured in the app (vs. paper) | ≥ 95% |
| Owner calls/messages asking for status | −70% |
| Inward vehicle turnaround time | −30% |
| Order-to-dispatch time | −25% |
| Unexplained stock variance | < 0.5% |
| Receivables > 60 days | −40% |
| Extraction % visibility | Daily, per shift (from roughly monthly today) |
| Time to prepare the daily MIS report | From ~1 hour to 0 (automatic) |

## 14. Release plan

| Phase | Timeline (indicative) | Scope |
|---|---|---|
| **Phase 0: Discovery** | 2–3 weeks | Walk the mill floor with every role, map current registers and forms, collect sample data, finalize masters, choose tech stack |
| **Phase 1: MVP** | 8–10 weeks | Masters, RBAC, gate/weighbridge (manual), QC, production log, packing, inventory, sales orders with credit approval, dispatch/loading tasks, invoicing, payments, notifications (push + WhatsApp), owner/manager dashboards, daily summary, Hindi/English, offline mode |
| **Pilot** | 3–4 weeks | Run in parallel with the existing registers; fix gaps; train each role |
| **Phase 2** | 8 weeks | Weighbridge integration, e-invoice/e-way bill, Tally sync, barcode/QR, maintenance module, attendance, anomaly alerts, AI assistant, demand forecast |
| **Phase 3** | Ongoing | IoT/sensors, wheat buying advisor, price recommendations, credit risk scoring, customer ordering portal/WhatsApp bot, multi-mill support |

## 15. Rollout and adoption

- **Champions:** pick one champion per department to help colleagues and relay feedback.
- **Training:** short role-specific videos in Hindi; in-app tooltips on first use.
- **Parallel run:** keep paper registers for 2–4 weeks during the pilot, then retire them one department at a time.
- **Leadership usage:** the owner approves orders and reviews summaries in the app from day one, which signals to everyone that the app is the source of truth.
- **Feedback loop:** in-app "report a problem" with voice notes; weekly review of issues during the pilot.

## 16. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Floor staff resist or find the app hard | Voice input, local language, minimal fields, shared devices, champions, simple training |
| Poor connectivity in the mill or field | Offline-first design with background sync |
| Data entry is skipped, so insights are wrong | Workflow gating (e.g., no dispatch without a loading confirmation), auto-generated tasks, daily completeness score per department |
| Manual weight entries are manipulated | Weighbridge integration, photo evidence, tolerance alerts, audit logs |
| Over-scoping delays the launch | Strict MVP scope; AI features come after clean data exists |
| Dependency on WhatsApp API costs/policies | Push notifications as the primary channel, SMS fallback, templated messages only |

## 17. Open questions

1. Monthly milling capacity and number of shifts? (Affects data volumes and shift design.)
2. Which products and pack sizes are sold today (aata, maida, sooji, chokar, others such as besan or multigrain)?
3. Is there a weighbridge on-site, and what make/model is its indicator?
4. Which accounting software is used today (Tally Prime, Busy, other)? Should the app replace invoicing or only feed it?
5. Sales model: direct to retailers, through distributors, bulk/institutional, or all three? Is there a price list per customer or per region?
6. Are delivery vehicles owned, hired per trip, or customer pickup?
7. How many users per role, and do floor staff have their own smartphones?
8. Which languages are needed besides Hindi and English?
9. Build approach: custom build, low-code, or customizing an existing ERP? Budget and target launch date?
10. Should customers and suppliers get their own access (portal/WhatsApp bot) in a later phase?

## 18. Glossary

| Term | Meaning |
|---|---|
| **Aata** | Whole-wheat flour |
| **Maida** | Refined wheat flour |
| **Sooji / Rava** | Semolina |
| **Chokar** | Wheat bran (by-product, sold as cattle feed) |
| **Extraction rate** | Percentage of wheat input that becomes a given product |
| **Tempering / conditioning** | Adding water to wheat and resting it before milling |
| **Bardana** | Jute/PP bags used for wheat or flour |
| **Mandi** | Agricultural wholesale market |
| **Gross / tare / net** | Loaded vehicle weight / empty vehicle weight / difference |
| **DSO** | Days sales outstanding (average collection time) |
| **MIS** | Management information system report |

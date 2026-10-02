# One chain from wheat to money: who does what, who sees what

## The chain (every step leaves a record; nothing moves without the step before it)
| # | Step | Who does it | Record that is created | Built? |
|---|---|---|---|---|
| 1 | Wheat truck arrives | Gate | Wheat lot (truck, supplier, time) | Yes |
| 2 | Weigh in and out | Gate (weighbridge) | Weights on the lot; net weight; gap vs supplier slip flagged above 0.5% | Yes |
| 3 | Lab check | QC | Moisture and foreign matter on the lot; fail above 14% / 2% blocks acceptance | Yes |
| 4 | Accepted wheat goes into stock | System | Stock entry into the raw wheat store | Yes |
| 5 | Milling batch | Production | Wheat used, flour/bran/waste out, extraction %, loss %; low yield or high loss flagged | Yes |
| 6 | Downtime | Production | Machine stop log | Yes |
| 7 | Packing | Packing | Bags by pack size added to finished stock | Yes |
| 8 | Customer order | Sales | Order with credit and stock check; below-price or over-credit needs the owner | Yes |
| 9 | Approval | Owner (Manager for normal orders) | Approval with name and time | Yes |
| 10 | Loading | Warehouse | Loading task, stock out | Yes |
| 11 | Invoice, e-way bill above Rs 50,000 | Accounts | Invoice before the truck can leave | Yes |
| 12 | Dispatch | Dispatch | Truck sent | Yes |
| 13 | Delivery | Driver | Delivery marked done | Yes (photo proof not yet) |
| 14 | Money collected | Driver / Accounts | Payment, oldest invoice first; bank needs a UTR | Yes |
| 15 | Owner sees the day | Owner | Dashboard, ageing, alerts, stock and profit reports | Yes |

Any important change (price, credit limit, approval) needs a reason and goes to a log nobody can edit.

## Who sees what (home screen shows only that person's tasks)
- **Owner:** approvals, today at the mill, dues, alerts, reports. Sees everything, approves exceptions.
- **Manager:** trucks at the mill, stock. Approves normal orders.
- **Sales:** new order, my orders, dues.
- **Purchase / Gate:** truck entry, weighbridge.
- **QC:** wheat lab check.
- **Production:** milling batch, downtime.
- **Packing:** pack bags, stock.
- **Warehouse:** loading queue only.
- **Dispatch:** send trucks only.
- **Driver:** own deliveries and collect payment only.
- **Accounts:** bills and payments, dues.
- **Auditor:** change log (read only).
One person can hold several roles and gets the tasks of all of them.

## Where things can still go untracked (honest gaps)
1. **Buying side has no order or price:** "Supplier rates" is a placeholder, so there is no purchase order, agreed rate, supplier invoice or payment to the farmer or trader. The money going out is not tracked yet.
2. **Wheat storage:** stock is one raw-wheat total. No silo or godown split, and no wheat issued to milling by lot, so you cannot trace a bag of flour back to a wheat lot.
3. **Flour QC:** "Check flour" is a placeholder.
4. **Plan production:** placeholder.
5. **Delivery photo proof and customer signature:** not built.
6. **Returns, shortage claims and credit notes:** not built.
7. **Change log screen for the auditor:** the log is kept on the server, the phone screen is a placeholder.
8. **Real server not yet used by the phone:** all of this was tested on demo data.

Recommended next order: 1 (buying and supplier payment), then 2 (lot-to-bag traceability), then 5, 3, 6.

# astrasun

Frappe app with the Atulyaa mill-specific parts that ERPNext does not provide.
ERPNext (with India Compliance) does accounts, stock, GST, purchase and sales documents.

## What is here (Phase 1: Foundation)
- **Mill roles and role profiles**: one profile per job (owner, sales, gate, loader...) that bundles the right ERPNext roles. See `astrasun/setup/roles.py`.
- **Audit with reason**: changing a critical field (prices, credit limits, item master, stock adjustments, cancelling financial documents) needs a reason. Each change is written to **Critical Change Log** with user, time, old value, new value and reason. Rules are in `astrasun/audit.py`.
- **Mill masters**: item groups, wheat, bulk flour, packed SKUs, empty bags, warehouses, milling and packing BOMs. See `astrasun/setup/masters.py`. Created when the ERPNext setup wizard finishes, or by running:
  `bench --site <site> execute astrasun.setup.masters.setup_mill --kwargs "{'company': '<Company>'}"`

Masters use placeholder values (pack sizes, milling ratios) until the Phase 0 workshop confirms them.

## Tests
`bench --site <site> run-tests --app astrasun`

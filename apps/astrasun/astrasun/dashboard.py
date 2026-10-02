"""Owner view: what happened today, who owes what, and what needs a look."""

import frappe
from frappe import _
from frappe.utils import add_days, flt, getdate, nowdate

OWNER_ROLES = ("Mill Owner", "Mill Manager", "Mill Auditor")
AGEING = (("0-30", 0, 30), ("31-60", 31, 60), ("61+", 61, 100000))


def _require():
	if not set(frappe.get_roles()).intersection(OWNER_ROLES):
		frappe.throw(_("Only the owner or a manager can see this"), frappe.PermissionError)


def _sum(doctype, field, filters):
	rows = frappe.get_all(doctype, filters=filters, fields=[f"sum({field}) as total"])
	return flt(rows[0].total) if rows else 0


def ageing():
	"""Money owed by customers, by how old the bill is."""
	today = getdate(nowdate())
	buckets = {name: 0.0 for name, _lo, _hi in AGEING}
	for inv in frappe.get_all(
		"Sales Invoice",
		filters={"docstatus": 1, "outstanding_amount": [">", 0]},
		fields=["posting_date", "outstanding_amount"],
	):
		days = (today - getdate(inv.posting_date)).days
		for name, lo, hi in AGEING:
			if lo <= days <= hi:
				buckets[name] += flt(inv.outstanding_amount)
				break
	return buckets


def alerts(days=7):
	"""Things the owner should look at: weight gaps, low yield, big downtime."""
	since = add_days(nowdate(), -days)
	items = []
	for lot in frappe.get_all(
		"Wheat Lot",
		filters={"weight_alert": 1, "modified": [">=", since]},
		fields=["name", "vehicle_no", "supplier_name", "weight_gap_kg", "weight_gap_pct"],
		order_by="modified desc",
	):
		items.append(
			{
				"kind": "weight",
				"ref": lot.name,
				"text": f"{lot.vehicle_no} {lot.supplier_name or ''}: {lot.weight_gap_kg:+.0f} kg ({lot.weight_gap_pct:.1f}%)",
			}
		)
	for b in frappe.get_all(
		"Milling Batch",
		filters={"low_yield": 1, "creation": [">=", since]},
		fields=["name", "shift", "extraction_pct", "loss_kg"],
		order_by="creation desc",
	):
		items.append(
			{
				"kind": "yield",
				"ref": b.name,
				"text": f"{b.shift} shift: extraction {b.extraction_pct:.1f}%, loss {b.loss_kg:.0f} kg",
			}
		)
	for d in frappe.get_all(
		"Machine Downtime",
		filters={"minutes": [">=", 60], "creation": [">=", since]},
		fields=["name", "machine", "minutes", "reason"],
		order_by="creation desc",
	):
		items.append(
			{"kind": "downtime", "ref": d.name, "text": f"{d.machine} stopped {d.minutes} min: {d.reason}"}
		)
	for so in frappe.get_all(
		"Sales Order",
		filters={"astrasun_approval_status": "Pending Approval", "astrasun_credit_breach": 1, "docstatus": 0},
		fields=["name", "customer_name", "grand_total"],
	):
		items.append(
			{
				"kind": "credit",
				"ref": so.name,
				"text": f"{so.customer_name}: order of {so.grand_total:,.0f} is over the credit limit",
			}
		)
	return items


@frappe.whitelist()
def today():
	_require()
	day = nowdate()
	batches = frappe.get_all(
		"Milling Batch", filters={"creation": [">=", day]}, fields=["wheat_kg", "flour_kg", "output_kg"]
	)
	wheat = sum(flt(b.wheat_kg) for b in batches)
	flour = sum(flt(b.flour_kg) for b in batches)
	return {
		"date": day,
		"sales_booked": _sum("Sales Order", "grand_total", {"docstatus": 1, "transaction_date": day}),
		"invoiced": _sum("Sales Invoice", "grand_total", {"docstatus": 1, "posting_date": day}),
		"collected": _sum(
			"Payment Entry", "paid_amount", {"docstatus": 1, "payment_type": "Receive", "posting_date": day}
		),
		"dues_total": _sum("Sales Invoice", "outstanding_amount", {"docstatus": 1, "outstanding_amount": [">", 0]}),
		"ageing": ageing(),
		"pending_approvals": frappe.db.count(
			"Sales Order", {"astrasun_approval_status": "Pending Approval", "docstatus": 0}
		),
		"trucks_in_yard": frappe.db.count("Wheat Lot", {"status": ["in", ["At Gate", "Weighed In", "On Hold", "Released"]]}),
		"trucks_to_dispatch": frappe.db.count(
			"Delivery Note", {"docstatus": 0, "astrasun_loading_status": ["in", ["Loading", "Loaded"]]}
		),
		"wheat_ground_kg": wheat,
		"flour_made_kg": flour,
		"extraction_pct": (flour / wheat * 100) if wheat else 0,
		"downtime_min": sum(
			frappe.get_all("Machine Downtime", filters={"creation": [">=", day]}, pluck="minutes")
		),
		"alerts": alerts(),
	}

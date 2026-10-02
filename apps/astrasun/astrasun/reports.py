"""Management reports built from recorded transactions: monthly stock statement and P&L."""

import frappe
from frappe import _
from frappe.utils import flt, get_first_day, get_last_day, getdate

REPORT_ROLES = ("Mill Owner", "Mill Manager", "Mill Accounts", "Mill Auditor")


def _require():
	if not set(frappe.get_roles()).intersection(REPORT_ROLES):
		frappe.throw(_("Only management and accounts can see reports"), frappe.PermissionError)


def _month(month):
	start = get_first_day(month or frappe.utils.nowdate())
	return getdate(start), getdate(get_last_day(start))


@frappe.whitelist()
def stock_statement(month=None):
	"""Opening + received - issued = closing for every item, straight from the stock ledger.

	`reconciled` is true only if closing also equals what the bins hold today
	(for the current month) and the rows add up.
	"""
	_require()
	start, end = _month(month)
	rows = frappe.db.sql(
		"""
		select item_code,
			sum(case when posting_date < %(start)s then actual_qty else 0 end) as opening,
			sum(case when posting_date between %(start)s and %(end)s and actual_qty > 0 then actual_qty else 0 end) as received,
			sum(case when posting_date between %(start)s and %(end)s and actual_qty < 0 then -actual_qty else 0 end) as issued,
			sum(case when posting_date <= %(end)s then actual_qty else 0 end) as closing
		from `tabStock Ledger Entry`
		where is_cancelled = 0 and posting_date <= %(end)s
		group by item_code
		order by item_code
		""",
		{"start": start, "end": end},
		as_dict=True,
	)
	items = []
	for r in rows:
		opening, received, issued, closing = (flt(r[k]) for k in ("opening", "received", "issued", "closing"))
		items.append(
			{
				"item_code": r.item_code,
				"opening": opening,
				"received": received,
				"issued": issued,
				"closing": closing,
				"ok": abs(opening + received - issued - closing) < 0.001,
			}
		)
	reconciled = all(i["ok"] for i in items)
	if end >= getdate(frappe.utils.nowdate()):
		bins = {
			b.item_code: flt(b.qty)
			for b in frappe.get_all("Bin", fields=["item_code", "sum(actual_qty) as qty"], group_by="item_code")
		}
		reconciled = reconciled and all(abs(bins.get(i["item_code"], 0) - i["closing"]) < 0.001 for i in items)
	return {"from": str(start), "to": str(end), "items": items, "reconciled": reconciled}


@frappe.whitelist()
def profit_and_loss(month=None):
	"""Sales less the cost of what was delivered, from invoices and the stock ledger."""
	_require()
	start, end = _month(month)
	sales = flt(
		frappe.db.sql(
			"""select sum(net_total) from `tabSales Invoice`
			where docstatus = 1 and posting_date between %s and %s""",
			(start, end),
		)[0][0]
	)
	cogs = flt(
		frappe.db.sql(
			"""select sum(-stock_value_difference) from `tabStock Ledger Entry`
			where is_cancelled = 0 and voucher_type = 'Delivery Note' and posting_date between %s and %s""",
			(start, end),
		)[0][0]
	)
	collected = flt(
		frappe.db.sql(
			"""select sum(paid_amount) from `tabPayment Entry`
			where docstatus = 1 and payment_type = 'Receive' and posting_date between %s and %s""",
			(start, end),
		)[0][0]
	)
	profit = sales - cogs
	return {
		"from": str(start),
		"to": str(end),
		"sales": sales,
		"cost_of_goods": cogs,
		"gross_profit": profit,
		"margin_pct": (profit / sales * 100) if sales else 0,
		"collected": collected,
	}

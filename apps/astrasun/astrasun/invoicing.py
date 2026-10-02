"""Invoice before dispatch (DECISIONS D5).

A loaded truck is billed from what was actually loaded. For consignments over
Rs 50,000 the e-way bill number must be recorded too. Only then can the truck
leave: dispatch submits the Delivery Note, which moves the stock out.
"""

import frappe
from frappe import _
from frappe.utils import flt, nowdate

from astrasun import audit
from astrasun.loading import LOADED, _as_system, _task

BILLER_ROLES = ("Mill Accounts", "Mill Manager", "Mill Owner")
DISPATCH_ROLES = ("Mill Dispatch", "Mill Manager", "Mill Owner")
DISPATCHED = "Dispatched"

# Goods worth more than this need an e-way bill to move by road
EWAY_BILL_LIMIT = 50000


class InvoicingError(frappe.ValidationError):
	pass


def _require(roles, message):
	if not set(frappe.get_roles()).intersection(roles):
		frappe.throw(_(message), frappe.PermissionError)


def _view(dn):
	task = _task(dn)
	invoice = dn.astrasun_invoice
	task.update(
		{
			"invoice": invoice,
			"invoice_total": flt(frappe.db.get_value("Sales Invoice", invoice, "grand_total"))
			if invoice
			else 0,
			"eway_bill_no": dn.astrasun_eway_bill_no,
			"eway_bill_needed": flt(dn.grand_total) > EWAY_BILL_LIMIT,
			"total": flt(dn.grand_total),
		}
	)
	return task


@frappe.whitelist()
def to_invoice():
	"""Loaded trucks that have no invoice yet."""
	_require(BILLER_ROLES, "Only accounts staff can invoice")
	names = frappe.get_all(
		"Delivery Note",
		filters={"docstatus": 0, "astrasun_loading_status": LOADED, "astrasun_invoice": ["is", "not set"]},
		order_by="creation asc",
		pluck="name",
	)
	return [_view(frappe.get_doc("Delivery Note", n)) for n in names]


@frappe.whitelist()
def to_dispatch():
	"""Invoiced trucks that have not left."""
	_require(DISPATCH_ROLES, "Only dispatch staff can send trucks")
	names = frappe.get_all(
		"Delivery Note",
		filters={"docstatus": 0, "astrasun_loading_status": LOADED, "astrasun_invoice": ["is", "set"]},
		order_by="creation asc",
		pluck="name",
	)
	return [_view(frappe.get_doc("Delivery Note", n)) for n in names]


@frappe.whitelist()
def invoice(name, eway_bill_no=None):
	"""Bill a loaded truck from the bags actually loaded."""
	_require(BILLER_ROLES, "Only accounts staff can invoice")
	from erpnext.selling.doctype.sales_order.sales_order import make_sales_invoice

	dn = frappe.get_doc("Delivery Note", name)
	if dn.docstatus != 0 or dn.astrasun_loading_status != LOADED:
		frappe.throw(_("Only a loaded truck can be invoiced"), InvoicingError)
	if dn.astrasun_invoice:
		frappe.throw(_("This truck is already invoiced"), InvoicingError)
	eway = (eway_bill_no or "").strip()
	if flt(dn.grand_total) > EWAY_BILL_LIMIT and not eway:
		frappe.throw(_("An e-way bill number is needed for this much goods"), InvoicingError)

	loaded = {r.so_detail: flt(r.qty) for r in dn.items}
	sales_order = dn.items[0].against_sales_order
	with _as_system():
		si = make_sales_invoice(sales_order)
		si.items = [row for row in si.items if row.so_detail in loaded]
		for row in si.items:
			row.qty = loaded[row.so_detail]
		si.set_posting_time = 0
		si.posting_date = nowdate()
		si.update_stock = 0
		si.insert()
		si.submit()
		dn.astrasun_invoice = si.name
		dn.astrasun_eway_bill_no = eway or None
		dn.save()
	audit.log(si, "Approval", f"Invoiced truck {dn.astrasun_vehicle_no} ({dn.name})")
	return _view(dn)


@frappe.whitelist()
def dispatch(name):
	"""Let the truck leave. Needs an invoice (and an e-way bill for big loads)."""
	_require(DISPATCH_ROLES, "Only dispatch staff can send trucks")
	dn = frappe.get_doc("Delivery Note", name)
	if dn.docstatus != 0 or dn.astrasun_loading_status != LOADED:
		frappe.throw(_("This truck is not ready to leave"), InvoicingError)
	if not dn.astrasun_invoice:
		frappe.throw(_("Invoice first. The truck cannot leave without one."), InvoicingError)
	if flt(dn.grand_total) > EWAY_BILL_LIMIT and not dn.astrasun_eway_bill_no:
		frappe.throw(_("The truck cannot leave without an e-way bill"), InvoicingError)
	with _as_system():
		dn.astrasun_loading_status = DISPATCHED
		dn.save()
		dn.submit()
	return _view(dn)

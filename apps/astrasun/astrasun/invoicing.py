"""Invoice before dispatch (DECISIONS D5).

A loaded truck is billed from what was actually loaded, when the warehouse taps
Print bill. Only then can the truck leave: dispatch submits the Delivery Note,
which moves the stock out. The e-way bill is not part of the app yet (v2).
"""

import frappe
from frappe import _
from frappe.utils import flt, nowdate
from frappe.utils.pdf import get_pdf

from astrasun import audit
from astrasun.loading import CHANGE_REQUESTED, LOADED, _as_system, _task

BILLER_ROLES = ("Mill Warehouse", "Mill Accounts", "Mill Manager", "Mill Owner")
DISPATCH_ROLES = ("Mill Warehouse", "Mill Dispatch", "Mill Manager", "Mill Owner")
DISPATCHED = "Dispatched"


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
			"total": flt(dn.grand_total),
			"change_requested": dn.astrasun_change_status == CHANGE_REQUESTED,
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


def _edit_waiting(dn):
	return bool(
		dn.items
		and frappe.db.get_value("Sales Order", dn.items[0].against_sales_order, "astrasun_edit_json")
	)


@frappe.whitelist()
def invoice(name):
	"""Print bill: bill a loaded truck from the bags actually loaded."""
	_require(BILLER_ROLES, "Only the warehouse or accounts staff can bill a truck")
	from erpnext.selling.doctype.sales_order.sales_order import make_sales_invoice

	dn = frappe.get_doc("Delivery Note", name)
	if dn.docstatus != 0 or dn.astrasun_loading_status != LOADED:
		frappe.throw(_("Only a loaded truck can be invoiced"), InvoicingError)
	if dn.astrasun_invoice:
		frappe.throw(_("This truck is already invoiced"), InvoicingError)
	if dn.astrasun_change_status == CHANGE_REQUESTED or _edit_waiting(dn):
		frappe.throw(_("A change to this load is waiting for the owner"), InvoicingError)

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
		dn.save()
	audit.log(si, "Approval", f"Invoiced truck {dn.astrasun_vehicle_no} ({dn.name})")
	return _view(dn)


@frappe.whitelist()
def bill_pdf(name):
	"""The truck's bill as a PDF, for the phone to print."""
	_require((*BILLER_ROLES, *DISPATCH_ROLES), "Only the warehouse or accounts staff can print bills")
	invoice_name = frappe.db.get_value("Delivery Note", name, "astrasun_invoice")
	if not invoice_name:
		frappe.throw(_("This truck has no bill yet"), InvoicingError)
	with _as_system():
		# The PDF tool runs inside the server and cannot always fetch pictures or styles by their web
		# address, which fails the whole bill; whatever it cannot fetch is left out instead.
		html = frappe.get_print("Sales Invoice", invoice_name, no_letterhead=1)
		pdf = get_pdf(html, {"load-error-handling": "ignore", "load-media-error-handling": "ignore"})
	frappe.local.response.filename = f"{invoice_name}.pdf"
	frappe.local.response.filecontent = pdf
	frappe.local.response.type = "pdf"


@frappe.whitelist()
def dispatch(name):
	"""Let the truck leave. Needs an invoice."""
	_require(DISPATCH_ROLES, "Only dispatch staff can send trucks")
	dn = frappe.get_doc("Delivery Note", name)
	if dn.docstatus != 0 or dn.astrasun_loading_status != LOADED:
		frappe.throw(_("This truck is not ready to leave"), InvoicingError)
	if not dn.astrasun_invoice:
		frappe.throw(_("Invoice first. The truck cannot leave without one."), InvoicingError)
	if dn.astrasun_change_status == CHANGE_REQUESTED or _edit_waiting(dn):
		frappe.throw(_("A change to this load is waiting for the owner"), InvoicingError)
	with _as_system():
		dn.astrasun_loading_status = DISPATCHED
		dn.save()
		dn.submit()
	return _view(dn)

"""Delivery proof: the driver records who received the goods."""

import frappe
from frappe import _
from frappe.utils import flt, now_datetime

from astrasun.invoicing import DISPATCHED, _view
from astrasun.loading import LoadingError, _as_system

DELIVERED = "Delivered"
DRIVER_ROLES = ("Mill Driver", "Mill Dispatch", "Mill Manager", "Mill Owner")


@frappe.whitelist()
def my_deliveries():
	"""Trucks that have left and are not yet delivered."""
	if not set(frappe.get_roles()).intersection(DRIVER_ROLES):
		frappe.throw(_("Only drivers can see deliveries"), frappe.PermissionError)
	names = frappe.get_all(
		"Delivery Note",
		filters={"docstatus": 1, "astrasun_loading_status": DISPATCHED},
		order_by="modified asc",
		pluck="name",
	)
	return [_view(frappe.get_doc("Delivery Note", n)) for n in names]


@frappe.whitelist()
def deliver(name, received_by, remarks=None):
	"""Record who received the goods; the truck's job is then done."""
	if not set(frappe.get_roles()).intersection(DRIVER_ROLES):
		frappe.throw(_("Only drivers can record deliveries"), frappe.PermissionError)
	received_by = (received_by or "").strip()
	if not received_by:
		frappe.throw(_("Write the name of the person who received the goods"), LoadingError)
	dn = frappe.get_doc("Delivery Note", name)
	if dn.docstatus != 1 or dn.astrasun_loading_status != DISPATCHED:
		frappe.throw(_("This truck has not left or is already delivered"), LoadingError)
	with _as_system():
		dn.astrasun_loading_status = DELIVERED
		dn.astrasun_received_by = received_by
		dn.astrasun_delivered_at = now_datetime()
		dn.astrasun_delivery_remarks = remarks
		dn.save()
	return _view(dn)

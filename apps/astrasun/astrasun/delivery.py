"""Delivery: the driver sees the orders on their vehicle and records who received the goods."""

import frappe
from frappe import _
from frappe.utils import now_datetime

from astrasun.invoicing import DISPATCHED, _view
from astrasun.loading import LOADED, LOADING, LoadingError, _as_system

DELIVERED = "Delivered"
DRIVER_ROLES = ("Mill Driver", "Mill Dispatch", "Mill Manager", "Mill Owner")
# These see every vehicle's orders; a driver sees only the vehicle they are assigned to
SEE_ALL_ROLES = ("Mill Dispatch", "Mill Manager", "Mill Owner")


def roles_see_all():
	return bool(set(frappe.get_roles()).intersection(SEE_ALL_ROLES))


@frappe.whitelist()
def my_deliveries():
	"""The orders on the driver's vehicle, from the moment the warehouse picks it until delivered."""
	roles = set(frappe.get_roles())
	if not roles.intersection(DRIVER_ROLES):
		frappe.throw(_("Only drivers can see deliveries"), frappe.PermissionError)
	filters = {"docstatus": ["in", [0, 1]], "astrasun_loading_status": ["in", [LOADING, LOADED, DISPATCHED]]}
	if not roles.intersection(SEE_ALL_ROLES):
		filters["astrasun_driver_user"] = frappe.session.user
	names = frappe.get_all("Delivery Note", filters=filters, order_by="modified asc", pluck="name")
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
	if not roles_see_all() and dn.astrasun_driver_user != frappe.session.user:
		frappe.throw(_("This order is not on your vehicle"), frappe.PermissionError)
	if dn.docstatus != 1 or dn.astrasun_loading_status != DISPATCHED:
		frappe.throw(_("This truck has not left or is already delivered"), LoadingError)
	with _as_system():
		dn.astrasun_loading_status = DELIVERED
		dn.astrasun_received_by = received_by
		dn.astrasun_delivered_at = now_datetime()
		dn.astrasun_delivery_remarks = remarks
		dn.save()
	return _view(dn)

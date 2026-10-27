"""Alerts for the bell on the phone: who must know when an order is placed, approved or paid.

Each alert is a standard ERPNext Notification Log row for one user, so it also shows in the
back-office bell. Sending an alert never stops the order or the payment it is about: a failure
is logged and ignored.
"""

import frappe
from frappe.utils import fmt_money

OWNER_ROLES = ("Mill Owner", "Mill Manager")


def users_with_role(roles):
	users = frappe.get_all(
		"Has Role", filters={"role": ["in", list(roles)], "parenttype": "User"}, pluck="parent"
	)
	return [
		u
		for u in set(users)
		if u not in ("Administrator", "Guest") and frappe.db.get_value("User", u, "enabled")
	]


def notify(users, subject, document_type, document_name, skip=None):
	"""Give each user (but not `skip`, who did the thing) one alert."""
	for user in set(users or []):
		if not user or user == skip:
			continue
		try:
			log = frappe.get_doc(
				{
					"doctype": "Notification Log",
					"for_user": user,
					"type": "Alert",
					"subject": subject,
					"document_type": document_type,
					"document_name": document_name,
					"from_user": frappe.session.user,
				}
			)
			log.flags.ignore_permissions = True
			log.insert()
		except Exception:
			frappe.log_error(title="Alert not sent", message=frappe.get_traceback())


def _money(amount):
	return fmt_money(amount, currency="INR") if amount is not None else ""


def order_placed(doc):
	"""A rep sent an order for approval: the owner and managers hear of it."""
	notify(
		users_with_role(OWNER_ROLES),
		f"New order {doc.name} from {doc.customer_name}: {_money(doc.grand_total)}",
		"Sales Order",
		doc.name,
		skip=frappe.session.user,
	)


def order_decided(doc, decision):
	"""The owner decided: the rep who sent it hears of it."""
	notify(
		[doc.astrasun_submitted_by or doc.owner],
		f"Your order {doc.name} for {doc.customer_name} was {decision}",
		"Sales Order",
		doc.name,
		skip=frappe.session.user,
	)


def money_collected(sales_order, customer_name, amount):
	"""Money was collected on an order: the owner and managers hear of it."""
	notify(
		users_with_role(OWNER_ROLES),
		f"{_money(amount)} collected from {customer_name} on {sales_order}",
		"Sales Order",
		sales_order,
		skip=frappe.session.user,
	)


@frappe.whitelist()
def my_alerts(limit=30):
	rows = frappe.get_all(
		"Notification Log",
		filters={"for_user": frappe.session.user, "type": "Alert"},
		fields=["name", "subject", "document_type", "document_name", "read", "creation"],
		order_by="creation desc",
		limit=int(limit),
	)
	return [
		{
			"id": r.name,
			"subject": r.subject,
			"order": r.document_name if r.document_type == "Sales Order" else None,
			"read": bool(r.read),
			"at": str(r.creation),
		}
		for r in rows
	]


@frappe.whitelist()
def unread_count():
	return frappe.db.count("Notification Log", {"for_user": frappe.session.user, "type": "Alert", "read": 0})


@frappe.whitelist()
def mark_read(names=None):
	"""Mark the given alerts (or all of the caller's alerts) as read."""
	import json

	names = json.loads(names) if isinstance(names, str) else names
	filters = {"for_user": frappe.session.user, "type": "Alert", "read": 0}
	if names:
		filters["name"] = ["in", names]
	for n in frappe.get_all("Notification Log", filters=filters, pluck="name"):
		frappe.db.set_value("Notification Log", n, "read", 1, update_modified=False)
	return unread_count()

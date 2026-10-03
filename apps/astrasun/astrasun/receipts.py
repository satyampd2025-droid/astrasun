"""Collections against an order.

A sales rep or a driver takes money from the shop and marks it Collected on the
order. In the evening the cash is handed in at the factory and the owner marks
it Settled: only then is the money booked as a Payment Entry against the order's
bills. Until then the order shows the money as collected, not yet handed in, so
everyone sees what is paid, what is with the rep or driver, and what is left.

The owner (or accounts) can also record money received directly at the factory;
that is settled at once.
"""

import frappe
from frappe import _
from frappe.utils import flt, now_datetime

from astrasun import payments

# Take money against an order. A rep only on their own orders, a driver only on orders on their vehicle.
FIELD_ROLES = ("Mill Sales", "Mill Driver")
OFFICE_ROLES = ("Mill Owner", "Mill Accounts", "Mill Manager")
SETTLER_ROLES = ("Mill Owner", "Mill Accounts")
MODES = payments.MODES
COLLECTED, SETTLED = "Collected", "Settled"


class CollectionError(frappe.ValidationError):
	pass


def _roles():
	return set(frappe.get_roles())


def order_invoices(sales_order):
	"""The order's bills (submitted, not returns), oldest first."""
	parents = frappe.get_all(
		"Sales Invoice Item",
		filters={"sales_order": sales_order, "docstatus": 1},
		pluck="parent",
		distinct=True,
	)
	if not parents:
		return []
	return frappe.get_all(
		"Sales Invoice",
		filters={"name": ["in", parents], "docstatus": 1, "is_return": 0},
		fields=["name", "company", "grand_total", "outstanding_amount"],
		order_by="posting_date asc, creation asc",
	)


def money(sales_order, invoices=None, pending=None):
	"""Billed, paid (settled), with the rep or driver (collected, not handed in) and what is left."""
	invoices = order_invoices(sales_order) if invoices is None else invoices
	billed = sum(flt(i.grand_total) for i in invoices)
	owed = sum(flt(i.outstanding_amount) for i in invoices)
	if pending is None:
		pending = flt(
			frappe.db.sql(
				"select coalesce(sum(amount), 0) from `tabMill Collection` where sales_order=%s and status=%s",
				(sales_order, COLLECTED),
			)[0][0]
		)
	return {
		"billed": billed,
		"paid": billed - owed,
		"with_collector": pending,
		"remaining": owed - pending,
	}


def pending_by_order(names):
	"""Collected, not yet settled, per order, for a whole list at once."""
	if not names:
		return {}
	rows = frappe.get_all(
		"Mill Collection",
		filters={"sales_order": ["in", names], "status": COLLECTED},
		fields=["sales_order", "amount"],
	)
	total = {}
	for r in rows:
		total[r.sales_order] = total.get(r.sales_order, 0) + flt(r.amount)
	return total


def _may_collect_on(so):
	"""Whether the caller can take money on this order."""
	roles = _roles()
	if roles.intersection(OFFICE_ROLES):
		return True
	user = frappe.session.user
	if "Mill Sales" in roles and user in (so.astrasun_submitted_by, so.owner):
		return True
	if "Mill Driver" in roles:
		return bool(
			frappe.db.sql(
				"""select 1 from `tabDelivery Note` dn
				join `tabDelivery Note Item` i on i.parent = dn.name
				where i.against_sales_order = %s and dn.docstatus < 2 and dn.astrasun_driver_user = %s
				limit 1""",
				(so.name, user),
			)
		)
	return False


def _row(c):
	return {
		"name": c.name,
		"sales_order": c.sales_order,
		"customer_name": c.customer_name,
		"amount": flt(c.amount),
		"mode": c.mode,
		"reference": c.reference,
		"status": c.status,
		"collected_by": c.collected_by,
		"collected_by_name": frappe.utils.get_fullname(c.collected_by),
		"collected_at": str(c.collected_at) if c.collected_at else None,
	}


@frappe.whitelist()
def collect(sales_order, amount, mode="Cash", reference=None):
	"""Mark money collected on an order. The owner or accounts recording it settles it at once."""
	if not _roles().intersection((*FIELD_ROLES, *OFFICE_ROLES)):
		frappe.throw(_("Only sales, drivers and the office can collect payment"), frappe.PermissionError)
	so = frappe.get_doc("Sales Order", sales_order)
	if not _may_collect_on(so):
		frappe.throw(_("You can only collect on your own orders"), frappe.PermissionError)
	amount = flt(amount)
	if amount <= 0:
		frappe.throw(_("Enter the amount received"), CollectionError)
	if mode not in MODES:
		frappe.throw(_("Payment mode must be Cash or Bank"), CollectionError)
	if mode == "Bank" and not (reference or "").strip():
		frappe.throw(_("Enter the UTR or cheque number"), CollectionError)
	invoices = order_invoices(sales_order)
	if not invoices:
		frappe.throw(_("There is no bill for this order yet"), CollectionError)
	left = money(sales_order, invoices)["remaining"]
	if amount > left:
		frappe.throw(_("More than is left to pay on this order ({0})").format(left), CollectionError)
	doc = frappe.get_doc(
		{
			"doctype": "Mill Collection",
			"sales_order": sales_order,
			"customer": so.customer,
			"customer_name": so.customer_name,
			"amount": amount,
			"mode": mode,
			"reference": (reference or "").strip() or None,
			"status": COLLECTED,
			"collected_by": frappe.session.user,
			"collected_at": now_datetime(),
		}
	)
	doc.flags.ignore_permissions = True
	doc.insert()
	if _roles().intersection(SETTLER_ROLES):
		_settle(doc)
	return {**_row(doc), **money(sales_order)}


def _settle(doc):
	"""Book the money as a Payment Entry against the order's open bills, oldest first."""
	invoices = [i for i in order_invoices(doc.sales_order) if flt(i.outstanding_amount) > 0]
	if sum(flt(i.outstanding_amount) for i in invoices) < flt(doc.amount):
		frappe.throw(_("The bills of this order owe less than {0}").format(doc.amount), CollectionError)
	left, refs = flt(doc.amount), []
	for inv in invoices:
		if left <= 0:
			break
		part = min(left, flt(inv.outstanding_amount))
		refs.append(
			{"reference_doctype": "Sales Invoice", "reference_name": inv.name, "allocated_amount": part}
		)
		left -= part
	pe = payments.receive(invoices[0].company, doc.customer, doc.amount, doc.mode, doc.reference, refs)
	doc.db_set(
		{
			"status": SETTLED,
			"settled_by": frappe.session.user,
			"settled_at": now_datetime(),
			"payment_entry": pe.name,
		}
	)
	doc.status = SETTLED


@frappe.whitelist()
def to_settle():
	"""Money collected and not yet handed in, grouped by who holds it. Owner and accounts."""
	if not _roles().intersection(SETTLER_ROLES):
		frappe.throw(_("Only the owner can settle cash"), frappe.PermissionError)
	rows = frappe.get_all(
		"Mill Collection",
		filters={"status": COLLECTED},
		fields="*",
		order_by="collected_at asc",
	)
	by_user = {}
	for c in rows:
		holder = by_user.setdefault(
			c.collected_by,
			{
				"user": c.collected_by,
				"name": frappe.utils.get_fullname(c.collected_by),
				"total": 0,
				"collections": [],
			},
		)
		holder["total"] += flt(c.amount)
		holder["collections"].append(_row(c))
	return sorted(by_user.values(), key=lambda h: h["name"])


@frappe.whitelist()
def settle(names):
	"""The cash was handed in: mark these collections settled (the owner, in the evening)."""
	if not _roles().intersection(SETTLER_ROLES):
		frappe.throw(_("Only the owner can settle cash"), frappe.PermissionError)
	names = frappe.parse_json(names) if isinstance(names, str) else names
	done = []
	for name in names:
		doc = frappe.get_doc("Mill Collection", name)
		if doc.status != COLLECTED:
			frappe.throw(_("{0} is already settled").format(name), CollectionError)
		_settle(doc)
		done.append(_row(doc))
	return done


@frappe.whitelist()
def my_collections():
	"""For a rep or driver: cash they hold, and their orders that still have money to collect."""
	roles = _roles()
	if not roles.intersection((*FIELD_ROLES, *OFFICE_ROLES)):
		frappe.throw(_("Only sales, drivers and the office can see collections"), frappe.PermissionError)
	user = frappe.session.user
	held = frappe.get_all(
		"Mill Collection",
		filters={"status": COLLECTED, "collected_by": user},
		fields="*",
		order_by="collected_at asc",
	)
	names = set()
	if "Mill Sales" in roles:
		names |= set(
			frappe.get_all(
				"Sales Order",
				filters={"docstatus": 1, "astrasun_submitted_by": user},
				or_filters={"owner": user},
				pluck="name",
			)
		)
	if "Mill Driver" in roles:
		names |= set(
			frappe.db.sql_list(
				"""select distinct i.against_sales_order from `tabDelivery Note Item` i
				join `tabDelivery Note` dn on dn.name = i.parent
				where dn.docstatus < 2 and dn.astrasun_driver_user = %s""",
				(user,),
			)
		)
	orders = []
	for name in sorted(names):
		invoices = order_invoices(name)
		if not invoices:
			continue
		m = money(name, invoices)
		if m["remaining"] > 0 or m["with_collector"] > 0:
			so = frappe.db.get_value("Sales Order", name, ["customer_name", "delivery_date"], as_dict=True)
			orders.append({"sales_order": name, "customer_name": so.customer_name, **m})
	return {
		"holding": sum(flt(c.amount) for c in held),
		"collections": [_row(c) for c in held],
		"orders": sorted(orders, key=lambda o: -o["remaining"]),
	}

"""Sales orders from the phone, with credit and stock checks and owner approval.

Flow (PRD Points 14, 15, 17): a sales rep saves an order and sends it for
approval. The system records the credit exposure and any stock shortage. An
owner or manager approves, rejects or sends it back. Nobody approves an order
they raised themselves. Orders that break the customer's credit limit can only
be approved by the owner. Approving submits the ERPNext Sales Order, which is
what the warehouse later loads against.

Status lives in `astrasun_approval_status` on the Sales Order:
Draft -> Pending Approval -> Approved | Rejected | Sent Back.
"""

import json

import frappe
from frappe import _
from frappe.utils import flt, nowdate

from astrasun import audit

APPROVER_ROLES = ("Mill Owner", "Mill Manager")
OWNER_ROLE = "Mill Owner"

DRAFT, PENDING, APPROVED, REJECTED, SENT_BACK = (
	"Draft",
	"Pending Approval",
	"Approved",
	"Rejected",
	"Sent Back",
)


class SelfApprovalError(frappe.ValidationError):
	pass


class CreditOverrideError(frappe.ValidationError):
	pass


def _company(item_code=None):
	"""The mill's company: the one the ordered item is set up for."""
	return (
		item_code and frappe.db.get_value("Item Default", {"parent": item_code}, "company")
	) or frappe.defaults.get_user_default("Company")


def _credit(customer, company, extra_amount):
	"""Outstanding (billed and unbilled), credit limit and exposure if this order is added."""
	from erpnext.selling.doctype.customer.customer import get_credit_limit, get_customer_outstanding

	outstanding = flt(get_customer_outstanding(customer, company, ignore_outstanding_sales_order=False))
	limit = flt(get_credit_limit(customer, company))
	exposure = outstanding + flt(extra_amount)
	return outstanding, limit, exposure


def _stock_short(doc):
	"""Items where the warehouse holds less than the order asks for."""
	from erpnext.stock.utils import get_latest_stock_qty

	short = []
	for row in doc.items:
		if not row.warehouse:
			continue
		available = flt(get_latest_stock_qty(row.item_code, row.warehouse))
		if available < flt(row.qty):
			short.append({"item_code": row.item_code, "wanted": flt(row.qty), "available": available})
	return short


def _below_price(doc):
	"""True if any line is sold under the item's list price (placeholder minimum, see DECISIONS)."""
	for row in doc.items:
		listed = frappe.db.get_value(
			"Item Price", {"item_code": row.item_code, "selling": 1}, "price_list_rate"
		)
		if listed and flt(row.rate) < flt(listed):
			return True
	return False


def _check(doc):
	"""Fill in the credit and stock facts the approver sees."""
	outstanding, limit, exposure = _credit(doc.customer, doc.company, doc.grand_total)
	doc.astrasun_credit_outstanding = outstanding
	doc.astrasun_credit_limit = limit
	doc.astrasun_credit_exposure = exposure
	# A limit of 0 means no limit has been set for this customer
	doc.astrasun_credit_breach = int(bool(limit) and exposure > limit)
	doc.astrasun_stock_short = int(bool(_stock_short(doc)))
	doc.astrasun_below_price = int(_below_price(doc))


def _warehouse(item_code, company):
	"""Where this item is kept, from the item's defaults for the company."""
	return frappe.db.get_value("Item Default", {"parent": item_code, "company": company}, "default_warehouse")


def create_order_doc(customer, items, delivery_date=None, remarks=None):
	company = _company(items[0]["item_code"])
	doc = frappe.get_doc(
		{
			"doctype": "Sales Order",
			"customer": customer,
			"company": company,
			"transaction_date": nowdate(),
			"delivery_date": delivery_date or nowdate(),
			"order_type": "Sales",
			"astrasun_approval_status": DRAFT,
			"astrasun_remarks": remarks,
			"items": [
				{
					"item_code": row["item_code"],
					"qty": flt(row["qty"]),
					"rate": flt(row["rate"]) if row.get("rate") is not None else None,
					"delivery_date": delivery_date or nowdate(),
					"warehouse": _warehouse(row["item_code"], company),
				}
				for row in items
			],
		}
	)
	doc.insert()
	_check(doc)
	doc.save()
	return doc


@frappe.whitelist()
def create_order(customer, items, delivery_date=None, remarks=None, send=1):
	"""Save an order from the phone; `send` also sends it for approval."""
	items = json.loads(items) if isinstance(items, str) else items
	if not items:
		frappe.throw(_("Add at least one item"))
	doc = create_order_doc(customer, items, delivery_date, remarks)
	if int(send):
		submit_for_approval(doc.name)
		doc.reload()
	return summary(doc)


@frappe.whitelist()
def submit_for_approval(name):
	doc = frappe.get_doc("Sales Order", name)
	if doc.docstatus != 0 or doc.astrasun_approval_status not in (DRAFT, SENT_BACK):
		frappe.throw(_("This order cannot be sent for approval"))
	_check(doc)
	doc.astrasun_approval_status = PENDING
	doc.astrasun_submitted_by = frappe.session.user
	doc.astrasun_approval_note = None
	doc.save()
	return summary(doc)


def _approver_check(doc):
	roles = set(frappe.get_roles())
	if not roles.intersection(APPROVER_ROLES):
		frappe.throw(_("Only the owner or a manager can decide on orders"), frappe.PermissionError)
	if frappe.session.user in (doc.astrasun_submitted_by, doc.owner):
		frappe.throw(_("You cannot approve your own order"), SelfApprovalError)
	if doc.astrasun_approval_status != PENDING:
		frappe.throw(_("This order is not waiting for approval"))
	return roles


@frappe.whitelist()
def approve(name, note=None):
	doc = frappe.get_doc("Sales Order", name)
	roles = _approver_check(doc)
	if doc.astrasun_credit_breach and OWNER_ROLE not in roles:
		frappe.throw(
			_("This order is over the customer's credit limit. Only the owner can approve it."),
			CreditOverrideError,
		)
	if doc.astrasun_below_price and OWNER_ROLE not in roles:
		frappe.throw(
			_("This order is below the list price. Only the owner can approve it."),
			CreditOverrideError,
		)
	doc.astrasun_approval_status = APPROVED
	doc.astrasun_approved_by = frappe.session.user
	doc.astrasun_approval_note = note
	doc.save()
	doc.submit()
	audit.log(
		doc,
		"Approval",
		note or ("Approved over credit limit" if doc.astrasun_credit_breach else "Approved"),
	)
	return summary(doc)


@frappe.whitelist()
def reject(name, reason):
	return _decide(name, REJECTED, reason)


@frappe.whitelist()
def send_back(name, reason):
	return _decide(name, SENT_BACK, reason)


def _decide(name, status, reason):
	if not (reason or "").strip():
		frappe.throw(_("Please give a reason"), audit.ReasonRequiredError)
	doc = frappe.get_doc("Sales Order", name)
	_approver_check(doc)
	doc.astrasun_approval_status = status
	doc.astrasun_approved_by = frappe.session.user
	doc.astrasun_approval_note = reason
	doc.save()
	audit.log(doc, "Approval", f"{status}: {reason}")
	return summary(doc)


def summary(doc):
	return {
		"name": doc.name,
		"customer": doc.customer,
		"customer_name": doc.customer_name,
		"status": doc.astrasun_approval_status,
		"total": flt(doc.grand_total),
		"delivery_date": str(doc.delivery_date),
		"submitted_by": doc.astrasun_submitted_by,
		"approved_by": doc.astrasun_approved_by,
		"note": doc.astrasun_approval_note,
		"credit_outstanding": flt(doc.astrasun_credit_outstanding),
		"credit_limit": flt(doc.astrasun_credit_limit),
		"credit_exposure": flt(doc.astrasun_credit_exposure),
		"credit_breach": bool(doc.astrasun_credit_breach),
		"stock_short": bool(doc.astrasun_stock_short),
		"below_min_price": bool(doc.astrasun_below_price),
		"items": [
			{"item_code": r.item_code, "item_name": r.item_name, "qty": flt(r.qty), "rate": flt(r.rate)}
			for r in doc.items
		],
	}


@frappe.whitelist()
def my_orders(limit=30):
	names = frappe.get_all(
		"Sales Order",
		filters={"astrasun_submitted_by": frappe.session.user},
		or_filters={"owner": frappe.session.user},
		order_by="modified desc",
		limit=int(limit),
		pluck="name",
	)
	return [summary(frappe.get_doc("Sales Order", n)) for n in names]


@frappe.whitelist()
def pending_approvals():
	if not set(frappe.get_roles()).intersection(APPROVER_ROLES):
		frappe.throw(_("Only the owner or a manager can see approvals"), frappe.PermissionError)
	names = frappe.get_all(
		"Sales Order",
		filters={"astrasun_approval_status": PENDING, "docstatus": 0},
		order_by="creation asc",
		pluck="name",
	)
	return [summary(frappe.get_doc("Sales Order", n)) for n in names]


@frappe.whitelist()
def catalog():
	"""Customers and sellable items (with today's list rate) for the order screen."""
	customers = frappe.get_all(
		"Customer", filters={"disabled": 0}, fields=["name", "customer_name"], order_by="customer_name asc"
	)
	items = frappe.get_all(
		"Item",
		filters={"item_group": "Finished Goods", "disabled": 0},
		fields=["item_code", "item_name"],
		order_by="item_name asc",
	)
	for item in items:
		item["rate"] = flt(
			frappe.db.get_value(
				"Item Price", {"item_code": item["item_code"], "selling": 1}, "price_list_rate"
			)
		)
	return {"customers": customers, "items": items}

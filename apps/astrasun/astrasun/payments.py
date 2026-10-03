"""Payment collection: money received is matched to the customer's oldest bills first."""

import frappe
from frappe import _
from frappe.utils import flt, nowdate

COLLECTOR_ROLES = ("Mill Driver", "Mill Accounts", "Mill Manager", "Mill Owner")
# A sales rep checks what a customer owes before taking an order (PRD), but does not receive money.
VIEWER_ROLES = (*COLLECTOR_ROLES, "Mill Sales")
MODES = ("Cash", "Bank")


class PaymentError(frappe.ValidationError):
	pass


def _check_role(roles, message):
	if not set(frappe.get_roles()).intersection(roles):
		frappe.throw(message, frappe.PermissionError)


def _open_invoices(customer):
	return frappe.get_all(
		"Sales Invoice",
		filters={"customer": customer, "docstatus": 1, "outstanding_amount": [">", 0]},
		fields=["name", "posting_date", "grand_total", "outstanding_amount", "company"],
		order_by="posting_date asc, creation asc",
	)


@frappe.whitelist()
def dues():
	"""Customers who owe money, biggest first, with their open bills."""
	_check_role(VIEWER_ROLES, _("Only sales, drivers and accounts staff can see customer dues"))
	rows = frappe.get_all(
		"Sales Invoice",
		filters={"docstatus": 1, "outstanding_amount": [">", 0]},
		fields=["customer", "customer_name", "name", "posting_date", "outstanding_amount"],
		order_by="posting_date asc, creation asc",
	)
	by_customer = {}
	for r in rows:
		c = by_customer.setdefault(
			r.customer, {"customer": r.customer, "customer_name": r.customer_name, "due": 0, "invoices": []}
		)
		c["due"] += flt(r.outstanding_amount)
		c["invoices"].append(
			{"name": r.name, "date": str(r.posting_date), "outstanding": flt(r.outstanding_amount)}
		)
	return sorted(by_customer.values(), key=lambda c: -c["due"])


def _account(company, mode):
	field = "default_cash_account" if mode == "Cash" else "default_bank_account"
	account = frappe.get_cached_value("Company", company, field)
	if not account:
		account = frappe.db.get_value(
			"Account",
			{"company": company, "account_type": mode, "is_group": 0},
			"name",
		)
	if not account:
		frappe.throw(_("No {0} account is set up for the mill").format(mode), PaymentError)
	return account


def receive(company, customer, amount, mode, reference, refs):
	"""Book money received from `customer` against the bills in `refs` (a Payment Entry)."""
	from erpnext.accounts.party import get_party_account

	user = frappe.session.user
	frappe.set_user("Administrator")
	try:
		pe = frappe.get_doc(
			{
				"doctype": "Payment Entry",
				"payment_type": "Receive",
				"company": company,
				"posting_date": nowdate(),
				"mode_of_payment": mode,
				"party_type": "Customer",
				"party": customer,
				"paid_from": get_party_account("Customer", customer, company),
				"paid_to": _account(company, mode),
				"paid_amount": amount,
				"received_amount": amount,
				"reference_no": (reference or "").strip() or f"{mode} {nowdate()}",
				"reference_date": nowdate(),
				"references": refs,
			}
		)
		pe.insert()
		pe.submit()
		pe.db_set("owner", user, update_modified=False)
	finally:
		frappe.set_user(user)
	return pe


@frappe.whitelist()
def collect(customer, amount, mode="Cash", reference=None):
	"""Receive money and match it to the oldest unpaid bills first."""
	_check_role(COLLECTOR_ROLES, _("Only drivers and accounts staff can collect payment"))
	amount = flt(amount)
	if amount <= 0:
		frappe.throw(_("Enter the amount received"), PaymentError)
	if mode not in MODES:
		frappe.throw(_("Payment mode must be Cash or Bank"), PaymentError)
	invoices = _open_invoices(customer)
	if not invoices:
		frappe.throw(_("This customer has nothing to pay"), PaymentError)
	due = sum(flt(i.outstanding_amount) for i in invoices)
	if amount > due:
		frappe.throw(_("More than the customer owes ({0})").format(due), PaymentError)
	if mode == "Bank" and not (reference or "").strip():
		frappe.throw(_("Enter the UTR or cheque number"), PaymentError)

	company = invoices[0].company
	left, refs = amount, []
	for inv in invoices:
		if left <= 0:
			break
		part = min(left, flt(inv.outstanding_amount))
		refs.append(
			{
				"reference_doctype": "Sales Invoice",
				"reference_name": inv.name,
				"allocated_amount": part,
			}
		)
		left -= part

	pe = receive(company, customer, amount, mode, reference, refs)
	return {
		"payment": pe.name,
		"amount": amount,
		"matched": [{"invoice": r["reference_name"], "amount": r["allocated_amount"]} for r in refs],
		"still_due": due - amount,
	}

"""Audit with mandatory reason (PRD Point 5).

Every critical change records user, time, old value, new value and reason in
Critical Change Log. A change without a reason is refused.

The reason comes from the `astrasun_change_reason` field on the document (the
web form and the phone app fill it), or from `doc.flags.change_reason` when
code makes the change. The field is cleared after each save, so a reason is
never reused for the next change.
"""

import json

import frappe
from frappe import _
from frappe.custom.doctype.custom_field.custom_field import create_custom_fields

REASON_FIELD = "astrasun_change_reason"

# Fields whose edits need a reason, per doctype. Child tables are compared as a whole.
CRITICAL_FIELDS = {
	"Item Price": ["price_list_rate", "price_list", "uom"],
	"Customer": ["credit_limits", "payment_terms", "default_price_list", "customer_group", "disabled"],
	"Supplier": ["gstin", "payment_terms", "disabled"],
	"Item": ["stock_uom", "valuation_rate", "standard_rate", "item_group", "gst_hsn_code", "disabled"],
	"Warehouse": ["disabled", "account", "parent_warehouse"],
}

# Submitting these is itself a stock adjustment, so it always needs a reason.
STOCK_ADJUSTMENTS = {
	"Stock Reconciliation": None,
	"Stock Entry": {"Material Issue", "Material Receipt"},
}

# Cancelling these needs a reason.
FINANCIAL_DOCUMENTS = [
	"Sales Invoice",
	"Purchase Invoice",
	"Payment Entry",
	"Journal Entry",
	"Delivery Note",
	"Purchase Receipt",
	"Sales Order",
	"Purchase Order",
	"Stock Entry",
	"Stock Reconciliation",
]

AUDITED_DOCTYPES = set(CRITICAL_FIELDS) | set(STOCK_ADJUSTMENTS) | set(FINANCIAL_DOCUMENTS)


def setup_custom_fields():
	field = {
		"fieldname": REASON_FIELD,
		"label": "Reason for Change",
		"fieldtype": "Small Text",
		"allow_on_submit": 1,
		"no_copy": 1,
		"print_hide": 1,
		"insert_after": None,
		"description": "Required when changing prices, credit limits, master data, stock or cancelling.",
	}
	create_custom_fields({dt: [field] for dt in AUDITED_DOCTYPES}, ignore_validate=True)


def _take_reason(doc):
	"""Return the reason given for this change and clear it from the document."""
	reason = (doc.flags.pop("change_reason", None) or doc.get(REASON_FIELD) or "").strip()
	if doc.meta.has_field(REASON_FIELD):
		doc.set(REASON_FIELD, None)
	return reason


def _require_reason(doc, what):
	reason = _take_reason(doc)
	if not reason:
		frappe.throw(
			_("Please enter a reason: {0}").format(what),
			title=_("Reason required"),
			exc=ReasonRequiredError,
		)
	doc.flags.audit_reason = reason
	return reason


class ReasonRequiredError(frappe.ValidationError):
	pass


def _comparable(doc, fieldname):
	df = doc.meta.get_field(fieldname)
	if not df:
		return None
	value = doc.get(fieldname)
	if df.fieldtype in frappe.model.table_fields:
		skip = {
			"name",
			"owner",
			"creation",
			"modified",
			"modified_by",
			"idx",
			"parent",
			"parentfield",
			"parenttype",
			"doctype",
			"docstatus",
		}
		rows = [{k: v for k, v in row.as_dict().items() if k not in skip} for row in value or []]
		return json.dumps(rows, sort_keys=True, default=str)
	if df.fieldtype in frappe.model.numeric_fieldtypes:
		return float(value or 0)
	return value or None


def _changed_fields(doc):
	before = doc.get_doc_before_save()
	if not before:
		return []
	changes = []
	for fieldname in CRITICAL_FIELDS.get(doc.doctype, []):
		old, new = _comparable(before, fieldname), _comparable(doc, fieldname)
		if old != new:
			changes.append((fieldname, old, new))
	return changes


def validate(doc, method=None):
	if doc.doctype not in CRITICAL_FIELDS or doc.is_new():
		return
	changes = _changed_fields(doc)
	if not changes:
		_take_reason(doc)
		return
	labels = ", ".join(_(doc.meta.get_label(f)) for f, _old, _new in changes)
	_require_reason(doc, _("changed {0}").format(labels))
	doc.flags.critical_changes = changes


def on_update(doc, method=None):
	changes = doc.flags.pop("critical_changes", None)
	if not changes:
		return
	reason = doc.flags.pop("audit_reason", None)
	for fieldname, old, new in changes:
		log(doc, "Update", reason, fieldname, old, new)


def _is_stock_adjustment(doc):
	if doc.doctype not in STOCK_ADJUSTMENTS:
		return False
	purposes = STOCK_ADJUSTMENTS[doc.doctype]
	return purposes is None or doc.get("purpose") in purposes


def before_submit(doc, method=None):
	# Checked at submit, not at draft, so drafts can be saved freely.
	if _is_stock_adjustment(doc):
		_require_reason(doc, _("stock adjustment"))


def on_submit(doc, method=None):
	if _is_stock_adjustment(doc):
		log(doc, "Stock Adjustment", doc.flags.pop("audit_reason", None))


def before_cancel(doc, method=None):
	if doc.doctype in FINANCIAL_DOCUMENTS:
		_require_reason(doc, _("cancelling {0}").format(_(doc.doctype)))


def on_cancel(doc, method=None):
	if doc.doctype in FINANCIAL_DOCUMENTS:
		log(doc, "Cancel", doc.flags.pop("audit_reason", None))


def log(doc, action, reason, fieldname=None, old=None, new=None):
	frappe.get_doc(
		{
			"doctype": "Critical Change Log",
			"reference_doctype": doc.doctype,
			"reference_name": doc.name,
			"action": action,
			"field_name": fieldname,
			"field_label": doc.meta.get_label(fieldname) if fieldname else None,
			"old_value": None if old is None else str(old),
			"new_value": None if new is None else str(new),
			"reason": reason,
			"user": frappe.session.user,
			"timestamp": frappe.utils.now_datetime(),
		}
	).insert(ignore_permissions=True)

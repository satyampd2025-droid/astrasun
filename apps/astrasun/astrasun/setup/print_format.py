import frappe
from frappe.custom.doctype.property_setter.property_setter import make_property_setter

NAME = "Atulyaa Tax Invoice"


def setup_bill_format():
	"""The bill the warehouse prints: a GST tax invoice laid out like the mill's own paper bill.

	It lives in templates/tax_invoice.html and is copied into a Print Format on every migrate, so a
	change to the file reaches the server with the next deploy. It becomes the default for invoices.
	"""
	with open(frappe.get_app_path("astrasun", "templates", "tax_invoice.html")) as f:
		html = f.read()
	values = {
		"doc_type": "Sales Invoice",
		"module": "Astrasun",
		"print_format_type": "Jinja",
		"custom_format": 1,
		"standard": "No",
		"disabled": 0,
		"html": html,
	}
	if frappe.db.exists("Print Format", NAME):
		frappe.db.set_value("Print Format", NAME, values)
	else:
		frappe.get_doc({"doctype": "Print Format", "name": NAME, **values}).insert(ignore_permissions=True)
	make_property_setter("Sales Invoice", None, "default_print_format", NAME, "Data")

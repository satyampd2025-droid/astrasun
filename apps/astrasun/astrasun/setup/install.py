import frappe

from astrasun.audit import setup_custom_fields
from astrasun.setup.masters import setup_mill
from astrasun.setup.loading import setup_loading_fields
from astrasun.setup.orders import setup_order_fields
from astrasun.setup.print_format import setup_bill_format
from astrasun.setup.roles import setup_roles, sync_users


def setup_stock_settings():
	"""The mill tracks orders, not stock, for now: a truck may leave whatever the books say is in the
	warehouse, so ERPNext must not refuse a negative balance."""
	frappe.db.set_single_value("Stock Settings", "allow_negative_stock", 1)


def after_install():
	setup_roles()
	setup_stock_settings()
	setup_custom_fields()
	setup_order_fields()
	setup_loading_fields()
	setup_bill_format()
	for company in frappe.get_all("Company", pluck="name"):
		setup_mill(company)


def after_migrate():
	setup_roles()
	setup_stock_settings()
	sync_users()
	setup_custom_fields()
	setup_order_fields()
	setup_loading_fields()
	setup_bill_format()


def setup_wizard_complete(args=None):
	company = (args or {}).get("company_name") or frappe.defaults.get_defaults().get("company")
	if company and frappe.db.exists("Company", company):
		setup_mill(company)

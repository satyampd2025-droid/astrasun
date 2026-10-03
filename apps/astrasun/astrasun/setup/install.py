import frappe

from astrasun.audit import setup_custom_fields
from astrasun.setup.masters import setup_mill
from astrasun.setup.loading import setup_loading_fields
from astrasun.setup.orders import setup_order_fields
from astrasun.setup.print_format import setup_bill_format
from astrasun.setup.roles import setup_roles, sync_users


def setup_stock_settings():
	"""Bags are tracked by batch; a truck's Delivery Note picks the oldest batch itself, so the warehouse
	never has to type one (otherwise ERPNext refuses with "Serial No / Batch No are mandatory")."""
	frappe.db.set_single_value(
		"Stock Settings",
		{"auto_create_serial_and_batch_bundle_for_outward": 1, "pick_serial_and_batch_based_on": "FIFO"},
	)


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

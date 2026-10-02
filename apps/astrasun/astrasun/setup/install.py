import frappe

from astrasun.audit import setup_custom_fields
from astrasun.setup.masters import setup_mill
from astrasun.setup.orders import setup_order_fields
from astrasun.setup.roles import setup_roles


def after_install():
	setup_roles()
	setup_custom_fields()
	setup_order_fields()
	for company in frappe.get_all("Company", pluck="name"):
		setup_mill(company)


def after_migrate():
	setup_roles()
	setup_custom_fields()
	setup_order_fields()


def setup_wizard_complete(args=None):
	company = (args or {}).get("company_name") or frappe.defaults.get_defaults().get("company")
	if company and frappe.db.exists("Company", company):
		setup_mill(company)

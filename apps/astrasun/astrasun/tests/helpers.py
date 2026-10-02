import frappe
from frappe.tests.utils import FrappeTestCase

from astrasun import orders

ITEM = "ATTA-50KG"


def _user(email, profile):
	if not frappe.db.exists("User", email):
		frappe.get_doc(
			{
				"doctype": "User",
				"email": email,
				"first_name": email.split("@")[0],
				"send_welcome_email": 0,
				"role_profile_name": profile,
			}
		).insert(ignore_permissions=True)
	return email


class MillFixture(FrappeTestCase):
	def setUp(self):
		frappe.set_user("Administrator")
		self.company = frappe.get_all("Company", pluck="name")[0]
		self.abbr = frappe.get_cached_value("Company", self.company, "abbr")
		self._open_fiscal_year()
		self.rep = _user("rep@example.com", "Mill Sales")
		self.manager = _user("manager@example.com", "Mill Manager")
		self.owner = _user("owner@example.com", "Mill Owner")
		self.warehouse = f"Finished Goods - {self.abbr}"
		self._stock(100)

	def tearDown(self):
		frappe.set_user("Administrator")

	def _open_fiscal_year(self):
		"""ERPNext's test fixtures limit the fiscal year to their own test companies."""
		year = frappe.get_doc("Fiscal Year", frappe.db.get_value("Fiscal Year", {"disabled": 0}))
		if self.company not in [row.company for row in year.companies]:
			year.append("companies", {"company": self.company})
			year.save()

	def _stock(self, qty):
		entry = frappe.get_doc(
			{
				"doctype": "Stock Entry",
				"stock_entry_type": "Material Receipt",
				"company": self.company,
				"items": [{"item_code": ITEM, "qty": qty, "basic_rate": 1000, "t_warehouse": self.warehouse}],
			}
		).insert()
		entry.flags.change_reason = "Opening stock for tests"
		entry.submit()

	def _customer(self, limit=None):
		user, _ = frappe.session.user, frappe.set_user("Administrator")
		try:
			return self._make_customer(limit)
		finally:
			frappe.set_user(user)

	def _make_customer(self, limit):
		customer = frappe.get_doc(
			{
				"doctype": "Customer",
				"customer_name": frappe.generate_hash(length=8),
				"customer_type": "Company",
				"customer_group": "Retailer",
			}
		).insert()
		if limit:
			customer.reload()
			customer.append("credit_limits", {"company": self.company, "credit_limit": limit})
			customer.flags.change_reason = "Test limit"
			customer.save()
		return customer.name

	def _order(self, customer, qty=10, rate=1500, send=1):
		frappe.set_user(self.rep)
		return orders.create_order(customer, [{"item_code": ITEM, "qty": qty, "rate": rate}], send=send)

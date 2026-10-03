import frappe
from frappe.tests.utils import FrappeTestCase

from astrasun import orders

ITEM = "ATTA-50KG"


def mill_company():
	"""The company the mill's items are set up for. Tests start from this and not from the site's default
	company: the test runner makes one of its own test companies the default."""
	return frappe.db.get_value("Item Default", {"parent": ITEM}, "company")


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
		self.company = mill_company()
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

	def make_dispatched(self, qty=10, customer=None):
		"""Order approved, loaded, invoiced and sent out. Returns (customer, delivery note, invoice)."""
		from astrasun import invoicing, loading

		customer = customer or self._customer(limit=10000000)
		loader = _user("loader@example.com", "Mill Warehouse")
		accounts = _user("accounts@example.com", "Mill Accounts")
		dispatcher = _user("dispatch@example.com", "Mill Dispatch")
		order = self._order(customer, qty=qty)
		frappe.set_user(self.manager)
		orders.approve(order["name"])
		frappe.set_user(loader)
		task = loading.start(order["name"])
		loading.mark_loaded(task["name"], "MP09AB1234", [{"item_code": ITEM, "qty": qty}])
		frappe.set_user(accounts)
		view = invoicing.invoice(task["name"], "271000123456")
		frappe.set_user(dispatcher)
		invoicing.dispatch(task["name"])
		return customer, task["name"], view["invoice"]

import frappe
from frappe.tests.utils import FrappeTestCase

from astrasun import orders
from astrasun.audit import ReasonRequiredError

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


class TestOrders(FrappeTestCase):
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

	def test_order_goes_to_pending_with_credit_facts(self):
		order = self._order(self._customer(limit=100000))
		self.assertEqual(order["status"], "Pending Approval")
		self.assertEqual(order["submitted_by"], self.rep)
		self.assertEqual(order["total"], 15000)
		self.assertEqual(order["credit_limit"], 100000)
		self.assertEqual(order["credit_exposure"], 15000)
		self.assertFalse(order["credit_breach"])
		self.assertFalse(order["stock_short"])

	def test_saved_but_not_sent_stays_draft(self):
		order = self._order(self._customer(), send=0)
		self.assertEqual(order["status"], "Draft")
		frappe.set_user(self.manager)
		self.assertNotIn(order["name"], [o["name"] for o in orders.pending_approvals()])

	def test_manager_approves_and_order_is_submitted(self):
		order = self._order(self._customer(limit=100000))
		frappe.set_user(self.manager)
		self.assertEqual([o["name"] for o in orders.pending_approvals()], [order["name"]])
		done = orders.approve(order["name"], "Good customer")
		self.assertEqual(done["status"], "Approved")
		self.assertEqual(done["approved_by"], self.manager)
		self.assertEqual(frappe.db.get_value("Sales Order", order["name"], "docstatus"), 1)
		log = frappe.get_all(
			"Critical Change Log",
			filters={"reference_name": order["name"], "action": "Approval"},
			pluck="reason",
		)
		self.assertEqual(log, ["Good customer"])

	def test_nobody_approves_their_own_order(self):
		frappe.set_user(self.manager)
		order = orders.create_order(self._customer(), [{"item_code": ITEM, "qty": 5, "rate": 1500}])
		self.assertRaises(orders.SelfApprovalError, orders.approve, order["name"])

	def test_sales_rep_cannot_decide_or_see_approvals(self):
		order = self._order(self._customer())
		self.assertRaises(frappe.PermissionError, orders.approve, order["name"])
		self.assertRaises(frappe.PermissionError, orders.pending_approvals)

	def test_over_credit_needs_the_owner(self):
		order = self._order(self._customer(limit=10000))  # order is 15,000
		self.assertTrue(order["credit_breach"])
		frappe.set_user(self.manager)
		self.assertRaises(orders.CreditOverrideError, orders.approve, order["name"])
		frappe.set_user(self.owner)
		done = orders.approve(order["name"], "Owner allows, pays Friday")
		self.assertEqual(done["status"], "Approved")

	def test_stock_shortage_is_flagged(self):
		order = self._order(self._customer(), qty=5000)
		self.assertTrue(order["stock_short"])

	def test_reject_and_send_back_need_a_reason(self):
		order = self._order(self._customer())
		frappe.set_user(self.manager)
		self.assertRaises(ReasonRequiredError, orders.reject, order["name"], " ")
		sent = orders.send_back(order["name"], "Please check the rate")
		self.assertEqual(sent["status"], "Sent Back")
		self.assertEqual(sent["note"], "Please check the rate")
		# the rep fixes it and sends it again
		frappe.set_user(self.rep)
		again = orders.submit_for_approval(order["name"])
		self.assertEqual(again["status"], "Pending Approval")
		frappe.set_user(self.manager)
		self.assertEqual(orders.reject(order["name"], "Customer cancelled")["status"], "Rejected")

	def test_my_orders_lists_only_mine(self):
		order = self._order(self._customer())
		self.assertIn(order["name"], [o["name"] for o in orders.my_orders()])
		frappe.set_user(self.manager)
		self.assertNotIn(order["name"], [o["name"] for o in orders.my_orders()])

	def test_catalog_lists_customers_and_packed_items(self):
		customer = self._customer()
		frappe.set_user(self.rep)
		data = orders.catalog()
		self.assertIn(customer, [c["name"] for c in data["customers"]])
		self.assertIn(ITEM, [i["item_code"] for i in data["items"]])

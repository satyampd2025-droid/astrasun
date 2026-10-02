import frappe

from astrasun import orders
from astrasun.audit import ReasonRequiredError
from astrasun.tests.helpers import ITEM, MillFixture


class TestOrders(MillFixture):
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

	def test_below_list_price_needs_the_owner(self):
		frappe.set_user("Administrator")
		if not frappe.db.exists("Item Price", {"item_code": ITEM, "selling": 1}):
			frappe.get_doc(
				{"doctype": "Item Price", "item_code": ITEM, "price_list": "Standard Selling", "selling": 1, "price_list_rate": 1500}
			).insert()
		order = self._order(self._customer(limit=1000000), rate=1000)
		self.assertTrue(order["below_min_price"])
		frappe.set_user(self.manager)
		with self.assertRaises(orders.CreditOverrideError):
			orders.approve(order["name"])
		frappe.set_user(self.owner)
		self.assertEqual(orders.approve(order["name"], "Dealer discount")["status"], "Approved")

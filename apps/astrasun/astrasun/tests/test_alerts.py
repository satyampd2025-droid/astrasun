import frappe

from astrasun import alerts, orders, receipts
from astrasun.tests.helpers import MillFixture


class TestAlerts(MillFixture):
	def setUp(self):
		super().setUp()
		frappe.db.delete("Notification Log", {"type": "Alert"})
		self.driver = "driver@example.com"

	def _mine(self, user):
		frappe.set_user(user)
		return alerts.my_alerts()

	def test_the_owner_hears_of_a_new_order_and_the_rep_of_the_decision(self):
		order = self._order(self._customer(limit=100000))
		for user in (self.owner, self.manager):
			got = self._mine(user)
			self.assertEqual(len(got), 1)
			self.assertIn(order["name"], got[0]["subject"])
			self.assertEqual(got[0]["order"], order["name"])
		self.assertEqual(self._mine(self.rep), [])  # the rep who placed it is not told about it

		frappe.set_user(self.owner)
		orders.approve(order["name"])
		got = self._mine(self.rep)
		self.assertEqual(len(got), 1)
		self.assertIn("approved", got[0]["subject"])
		self.assertEqual(len(self._mine(self.owner)), 1)  # the owner is not told about their own decision

	def test_a_turned_down_order_tells_the_rep(self):
		order = self._order(self._customer())
		frappe.set_user(self.owner)
		orders.reject(order["name"], "Too much credit")
		self.assertIn("rejected", self._mine(self.rep)[0]["subject"])

	def test_the_owner_hears_when_money_is_collected(self):
		customer, dn, invoice = self.make_dispatched(qty=10)
		order = frappe.db.get_value("Delivery Note Item", {"parent": dn}, "against_sales_order")
		frappe.db.delete("Notification Log", {"type": "Alert"})
		frappe.set_user(self.rep)
		receipts.collect(order, 5000, "Cash")
		got = self._mine(self.owner)
		self.assertEqual(len(got), 1)
		self.assertIn("collected", got[0]["subject"])
		self.assertIn(order, got[0]["subject"])

	def test_read_marks_clear_the_count(self):
		self._order(self._customer())
		frappe.set_user(self.owner)
		self.assertEqual(alerts.unread_count(), 1)
		self.assertEqual(alerts.mark_read(), 0)
		self.assertTrue(alerts.my_alerts()[0]["read"])

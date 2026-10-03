import frappe

from astrasun import delivery, orders, receipts
from astrasun.tests.helpers import MillFixture, _user


class TestReceipts(MillFixture):
	def setUp(self):
		super().setUp()
		# Collections from an earlier test must not show up in this one
		frappe.db.delete("Mill Collection")
		self.driver = "driver@example.com"
		self.other_rep = _user("rep2@example.com", "Mill Sales")
		self.accounts = _user("accounts@example.com", "Mill Accounts")

	def _billed_order(self, qty=10):
		"""An order the rep booked, billed, sent out and delivered by the driver. Returns (order, invoice, total)."""
		customer, dn, invoice = self.make_dispatched(qty=qty)
		order = frappe.db.get_value("Delivery Note Item", {"parent": dn}, "against_sales_order")
		frappe.set_user(self.driver)
		delivery.deliver(dn, "Ramesh Sharma")
		total = frappe.db.get_value("Sales Invoice", invoice, "grand_total")
		return order, invoice, total

	def _summary(self, order, user):
		frappe.set_user(user)
		return next(o for o in orders.my_orders() if o["name"] == order)

	def test_rep_collects_part_payment_and_the_owner_settles_it(self):
		order, invoice, total = self._billed_order()
		frappe.set_user(self.rep)
		got = receipts.collect(order, 5000, "Cash")
		self.assertEqual(got["status"], "Collected")
		self.assertEqual(got["with_collector"], 5000)
		self.assertEqual(got["remaining"], total - 5000)
		# The order shows it: paid so far, with the rep, and what is left
		mine = self._summary(order, self.rep)
		self.assertEqual(mine["with_collector"], 5000)
		self.assertEqual(mine["remaining"], total - 5000)
		self.assertEqual(mine["paid"], 0)  # not handed in yet
		self.assertEqual(mine["stage"], "Part paid")
		# The books do not move until the owner settles the cash
		self.assertEqual(frappe.db.get_value("Sales Invoice", invoice, "outstanding_amount"), total)

		frappe.set_user(self.owner)
		holders = receipts.to_settle()
		self.assertEqual([h["user"] for h in holders], [self.rep])
		self.assertEqual(holders[0]["total"], 5000)
		done = receipts.settle([c["name"] for c in holders[0]["collections"]])
		self.assertEqual(done[0]["status"], "Settled")
		self.assertEqual(frappe.db.get_value("Sales Invoice", invoice, "outstanding_amount"), total - 5000)
		self.assertEqual(receipts.to_settle(), [])
		mine = self._summary(order, self.rep)
		self.assertEqual((mine["paid"], mine["with_collector"], mine["remaining"]), (5000, 0, total - 5000))
		frappe.set_user(self.owner)
		with self.assertRaises(receipts.CollectionError):
			receipts.settle([done[0]["name"]])  # already settled

	def test_the_rest_can_be_collected_later_and_the_order_is_paid(self):
		order, invoice, total = self._billed_order()
		frappe.set_user(self.rep)
		receipts.collect(order, 5000)
		receipts.collect(order, total - 5000)
		self.assertEqual(self._summary(order, self.rep)["stage"], "Paid")
		with self.assertRaises(receipts.CollectionError):
			receipts.collect(order, 1)  # nothing left

	def test_collection_rules(self):
		order, invoice, total = self._billed_order()
		frappe.set_user(self.rep)
		with self.assertRaises(receipts.CollectionError):
			receipts.collect(order, 0)
		with self.assertRaises(receipts.CollectionError):
			receipts.collect(order, total + 1)  # more than is left
		with self.assertRaises(receipts.CollectionError):
			receipts.collect(order, 100, "Bank")  # needs a UTR
		with self.assertRaises(receipts.CollectionError):
			receipts.collect(order, 100, "Card")
		receipts.collect(order, 100, "Bank", "UTR123456")
		# Only the owner (or accounts) settles; the rep cannot mark their own cash handed in
		with self.assertRaises(frappe.PermissionError):
			receipts.to_settle()
		with self.assertRaises(frappe.PermissionError):
			receipts.settle(["anything"])

	def test_a_rep_collects_only_on_their_own_orders(self):
		order, _inv, _total = self._billed_order()
		frappe.set_user(self.other_rep)
		with self.assertRaises(frappe.PermissionError):
			receipts.collect(order, 100)
		self.assertEqual(receipts.my_collections()["orders"], [])
		frappe.set_user(self.rep)
		# Earlier tests leave their own orders behind, so look for this one among the rep's
		self.assertIn(order, [o["sales_order"] for o in receipts.my_collections()["orders"]])

	def test_a_driver_collects_on_orders_on_their_vehicle(self):
		order, _inv, _total = self._billed_order()
		other = _user("driver2@example.com", "Mill Driver")
		frappe.set_user(other)
		with self.assertRaises(frappe.PermissionError):
			receipts.collect(order, 100)
		frappe.set_user(self.driver)
		self.assertIn(order, [o["sales_order"] for o in receipts.my_collections()["orders"]])
		receipts.collect(order, 2500)
		held = receipts.my_collections()
		self.assertEqual(held["holding"], 2500)
		self.assertEqual(held["collections"][0]["sales_order"], order)

	def test_no_bill_no_collection(self):
		order = self._order(self._customer(limit=10000000))["name"]
		frappe.set_user(self.rep)
		with self.assertRaises(receipts.CollectionError):
			receipts.collect(order, 100)

	def test_the_owner_recording_money_at_the_factory_settles_it_at_once(self):
		order, invoice, total = self._billed_order()
		frappe.set_user(self.owner)
		got = receipts.collect(order, 3000, "Cash")
		self.assertEqual(got["status"], "Settled")
		self.assertEqual(frappe.db.get_value("Sales Invoice", invoice, "outstanding_amount"), total - 3000)
		self.assertEqual(receipts.to_settle(), [])
		frappe.set_user(self.accounts)
		self.assertEqual(receipts.collect(order, 1000)["status"], "Settled")

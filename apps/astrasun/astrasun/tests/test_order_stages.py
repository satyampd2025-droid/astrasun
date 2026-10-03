import frappe

from astrasun import delivery, invoicing, loading, orders, payments
from astrasun.tests.helpers import ITEM, MillFixture, _user


class TestOrderStages(MillFixture):
	"""The rep, the owner and the floor read one ladder, and it moves with the order."""

	def setUp(self):
		super().setUp()
		self.loader = _user("loader@example.com", "Mill Warehouse")
		self.accounts = _user("accounts@example.com", "Mill Accounts")
		self.dispatcher = _user("dispatch@example.com", "Mill Dispatch")
		self.driver = _user("driver@example.com", "Mill Driver")
		self.customer = self._customer(limit=10000000)

	def seen_by_rep(self, name):
		frappe.set_user(self.rep)
		return next(o for o in orders.my_orders() if o["name"] == name)

	def test_rep_follows_the_order_from_approval_to_payment(self):
		order = self._order(self.customer, qty=10)
		self.assertEqual(order["stage"], "Waiting for approval")
		self.assertEqual(self.seen_by_rep(order["name"])["stage"], "Waiting for approval")

		frappe.set_user(self.manager)
		self.assertEqual(orders.approve(order["name"])["stage"], "Approved")
		self.assertEqual(self.seen_by_rep(order["name"])["stage"], "Approved")

		frappe.set_user(self.loader)
		task = loading.start(order["name"])
		self.assertEqual(self.seen_by_rep(order["name"])["stage"], "Loading")
		frappe.set_user(self.loader)
		loading.mark_loaded(task["name"], "MP09AB1234", [{"item_code": ITEM, "qty": 10}])
		self.assertEqual(self.seen_by_rep(order["name"])["stage"], "Loaded")

		frappe.set_user(self.accounts)
		invoicing.invoice(task["name"], "271000123456")
		self.assertEqual(self.seen_by_rep(order["name"])["stage"], "Loaded")

		frappe.set_user(self.dispatcher)
		invoicing.dispatch(task["name"])
		seen = self.seen_by_rep(order["name"])
		self.assertEqual((seen["stage"], seen["tone"]), ("On the way", "go"))

		frappe.set_user(self.driver)
		delivery.deliver(task["name"], "Ramesh Sharma")
		self.assertEqual(self.seen_by_rep(order["name"])["stage"], "Delivered, payment pending")

		frappe.set_user(self.driver)
		still_due = payments.collect(self.customer, 5000)["still_due"]
		self.assertEqual(self.seen_by_rep(order["name"])["stage"], "Part paid")

		frappe.set_user(self.driver)
		payments.collect(self.customer, still_due)
		seen = self.seen_by_rep(order["name"])
		self.assertEqual((seen["stage"], seen["tone"]), ("Paid", "done"))
		self.assertEqual({row["state"] for row in seen["timeline"]}, {"done"})

	def test_orders_the_manager_has_not_approved_keep_their_own_word(self):
		order = self._order(self.customer, qty=10)
		frappe.set_user(self.manager)
		orders.send_back(order["name"], "Check the rate")
		self.assertEqual(self.seen_by_rep(order["name"])["stage"], "Sent Back")
		self.assertEqual(self.seen_by_rep(order["name"])["timeline"], [])

	def test_owner_and_manager_see_every_order_but_not_unsent_drafts(self):
		sent = self._order(self.customer)
		draft = self._order(self.customer, send=0)
		for user in (self.manager, self.owner):
			frappe.set_user(user)
			names = [o["name"] for o in orders.all_orders()]
			self.assertIn(sent["name"], names)
			self.assertNotIn(draft["name"], names)
		self.assertEqual(
			[o["stage"] for o in orders.all_orders() if o["name"] == sent["name"]], ["Waiting for approval"]
		)
		frappe.set_user(self.rep)
		with self.assertRaises(frappe.PermissionError):
			orders.all_orders()

	def test_truck_cards_use_the_same_words(self):
		order = self._order(self.customer, qty=10)
		frappe.set_user(self.manager)
		orders.approve(order["name"])

		frappe.set_user(self.loader)
		waiting = [w for w in loading.queue()["waiting"] if w["sales_order"] == order["name"]]
		self.assertEqual([w["stage"] for w in waiting], ["Approved"])
		task = loading.start(order["name"])
		self.assertEqual(task["stage"], "Loading")
		loaded = loading.mark_loaded(task["name"], "MP09AB1234", [{"item_code": ITEM, "qty": 10}])
		self.assertEqual(loaded["stage"], "Loaded")

		frappe.set_user(self.accounts)
		self.assertEqual(
			[t["stage"] for t in invoicing.to_invoice() if t["name"] == task["name"]], ["Loaded"]
		)
		invoicing.invoice(task["name"], "271000123456")

		frappe.set_user(self.dispatcher)
		self.assertEqual(
			[t["stage"] for t in invoicing.to_dispatch() if t["name"] == task["name"]], ["Loaded"]
		)
		invoicing.dispatch(task["name"])

		frappe.set_user(self.driver)
		self.assertEqual(
			[t["stage"] for t in delivery.my_deliveries() if t["name"] == task["name"]], ["On the way"]
		)

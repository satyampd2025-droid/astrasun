import frappe

from astrasun import invoicing, loading, orders
from astrasun.tests.helpers import ITEM, MillFixture, _user

OTHER = "ATTA-26KG"


class TestEditOrder(MillFixture):
	def setUp(self):
		super().setUp()
		self.loader = _user("loader@example.com", "Mill Warehouse")

	def _approved(self, qty=10):
		order = self._order(self._customer(limit=10000000), qty=qty)
		frappe.set_user(self.manager)
		orders.approve(order["name"])
		return order["name"]

	def _edit(self, user, name, items, reason="Shop wants a different mix"):
		frappe.set_user(user)
		return orders.edit_order(name, items, reason)

	def test_the_rep_edits_before_approval_and_it_waits_for_the_owner_again(self):
		order = self._order(self._customer(limit=10000000), qty=10)
		frappe.set_user(self.manager)
		orders.send_back(order["name"], "Check the bags")
		done = self._edit(self.rep, order["name"], [{"item_code": ITEM, "qty": 6}])
		self.assertEqual(done["status"], "Pending Approval")
		self.assertEqual(done["items"][0]["qty"], 6)
		self.assertEqual(done["items"][0]["rate"], 1500)

	def test_an_approved_order_keeps_its_items_until_the_owner_approves_the_edit(self):
		name = self._approved(10)
		done = self._edit(
			self.rep,
			name,
			[{"item_code": ITEM, "qty": 4}, {"item_code": OTHER, "qty": 3, "rate": 400}],
		)
		self.assertEqual(done["stage"], "Waiting for approval")
		self.assertEqual([i["qty"] for i in done["items"]], [10])
		self.assertEqual(len(done["edit"]["items"]), 2)
		self.assertFalse(done["can_edit"])
		frappe.set_user(self.manager)
		self.assertEqual([o["name"] for o in orders.pending_approvals()], [name])
		approved = orders.approve(name, "OK")
		self.assertEqual(approved["stage"], "Approved")
		self.assertIsNone(approved["edit"])
		by_item = {i["item_code"]: i["qty"] for i in approved["items"]}
		self.assertEqual(by_item, {ITEM: 4, OTHER: 3})
		self.assertEqual(approved["total"], 4 * 1500 + 3 * 400)

	def test_an_item_can_be_taken_off(self):
		name = self._approved(10)
		self._edit(
			self.rep, name, [{"item_code": ITEM, "qty": 5}, {"item_code": OTHER, "qty": 2, "rate": 400}]
		)
		frappe.set_user(self.manager)
		orders.approve(name)
		self._edit(self.rep, name, [{"item_code": OTHER, "qty": 2}])
		frappe.set_user(self.manager)
		done = orders.approve(name)
		self.assertEqual([i["item_code"] for i in done["items"]], [OTHER])

	def test_turned_down_edit_leaves_the_order_as_it_was(self):
		name = self._approved(10)
		self._edit(self.rep, name, [{"item_code": ITEM, "qty": 2}])
		frappe.set_user(self.manager)
		done = orders.send_back(name, "No, keep it")
		self.assertEqual(done["stage"], "Approved")
		self.assertEqual(done["items"][0]["qty"], 10)
		self.assertIsNone(done["edit"])
		self.assertTrue(done["can_edit"])

	def test_the_warehouse_edits_and_the_load_goes_back_to_start(self):
		name = self._approved(10)
		frappe.set_user(self.loader)
		task = loading.start(name)
		loading.mark_loaded(task["name"], "MP09AB1234", [{"item_code": ITEM, "qty": 10}])
		bill = invoicing.invoice(task["name"])["invoice"]
		self._edit(self.loader, name, [{"item_code": ITEM, "qty": 7}], "Only 7 bags fit")
		# While it waits nothing moves on the truck
		frappe.set_user(self.loader)
		with self.assertRaises(invoicing.InvoicingError):
			invoicing.dispatch(task["name"])
		self.assertTrue(loading.queue()["loading"][0]["change_requested"])
		frappe.set_user(self.manager)
		orders.approve(name)
		# The old bill is cancelled, the old load is gone and the order is back in the queue
		self.assertEqual(frappe.db.get_value("Sales Invoice", bill, "docstatus"), 2)
		self.assertFalse(frappe.db.exists("Delivery Note", task["name"]))
		frappe.set_user(self.loader)
		queue = loading.queue()
		self.assertEqual(queue["loading"], [])
		self.assertEqual(queue["waiting"][0]["items"][0]["qty"], 7)

	def test_nobody_edits_an_order_after_a_truck_left(self):
		_, dn, _inv = self.make_dispatched()
		name = frappe.db.get_value("Delivery Note Item", {"parent": dn}, "against_sales_order")
		for user in (self.rep, self.loader):
			frappe.set_user(user)
			with self.assertRaises(orders.EditError):
				orders.edit_order(name, [{"item_code": ITEM, "qty": 1}], "Too late")
		frappe.set_user(self.rep)
		self.assertFalse(orders.get_order(name)["can_edit"])

	def test_only_the_rep_who_booked_it_or_the_warehouse_may_edit(self):
		name = self._approved(10)
		other = _user("rep2@example.com", "Mill Sales")
		frappe.set_user(other)
		with self.assertRaises(frappe.PermissionError):
			orders.edit_order(name, [{"item_code": ITEM, "qty": 1}], "Mine now")
		frappe.set_user(self.rep)
		with self.assertRaises(orders.EditError):
			orders.edit_order(name, [{"item_code": ITEM, "qty": 1}], "  ")

	def test_the_person_who_asked_cannot_approve_the_edit(self):
		name = self._approved(10)
		self._edit(self.loader, name, [{"item_code": ITEM, "qty": 3}])
		frappe.set_user(self.loader)
		with self.assertRaises(frappe.PermissionError):
			orders.approve(name)

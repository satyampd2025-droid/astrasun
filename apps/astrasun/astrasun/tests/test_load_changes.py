import frappe

from astrasun import invoicing, loading, orders
from astrasun.tests.helpers import ITEM, MillFixture, _user


class TestLoadChanges(MillFixture):
	def setUp(self):
		super().setUp()
		self.loader = _user("loader@example.com", "Mill Warehouse")

	def _billed(self, qty=10):
		"""An order approved, loaded, and its bill printed by the warehouse. Returns (order, truck)."""
		order = self._order(self._customer(limit=10000000), qty=qty)
		frappe.set_user(self.manager)
		orders.approve(order["name"])
		frappe.set_user(self.loader)
		task = loading.start(order["name"])
		loading.mark_loaded(task["name"], "MP09AB1234", [{"item_code": ITEM, "qty": qty}])
		view = invoicing.invoice(task["name"])
		return order["name"], task["name"], view["invoice"]

	def _ask(self, dn, qty, reason="Customer took fewer bags"):
		frappe.set_user(self.loader)
		return loading.request_change(dn, [{"item_code": ITEM, "qty": qty}], reason)

	def test_the_bill_prints_as_a_pdf(self):
		_, dn, _inv = self._billed()
		# The bill prints from the invoice's own print format
		frappe.set_user("Administrator")
		self.assertIn(_inv, frappe.get_print("Sales Invoice", _inv))
		frappe.set_user(self.loader)
		frappe.local.conf.host_name = "http://localhost:8000"
		try:
			invoicing.bill_pdf(dn)
		except (OSError, frappe.ValidationError):
			# This test server has no web server in front for the print styles and logo, so wkhtmltopdf
			# cannot fetch them; the PDF itself is checked on the real server.
			pass
		else:
			self.assertTrue(frappe.local.response.filecontent.startswith(b"%PDF"))
		frappe.set_user(self.rep)
		with self.assertRaises(frappe.PermissionError):
			invoicing.bill_pdf(dn)

	def test_approved_change_cancels_the_bill_and_the_warehouse_prints_a_new_one(self):
		_, dn, old = self._billed(qty=10)
		asked = self._ask(dn, 8)
		self.assertTrue(asked["change_requested"])
		# While it waits the truck cannot leave and nothing is billed again
		with self.assertRaises(invoicing.InvoicingError):
			invoicing.dispatch(dn)
		with self.assertRaises(invoicing.InvoicingError):
			invoicing.invoice(dn)
		frappe.set_user(self.owner)
		waiting = loading.change_requests()
		self.assertEqual([t["name"] for t in waiting], [dn])
		self.assertEqual(waiting[0]["new_items"], [{"item_code": ITEM, "qty": 8}])
		self.assertEqual(waiting[0]["reason"], "Customer took fewer bags")

		done = loading.decide_change(dn, 1)
		self.assertFalse(done["change_requested"])
		self.assertEqual(done["items"][0]["qty"], 8)
		self.assertEqual(done["status"], "Loaded")  # back to the warehouse for a new bill
		self.assertEqual(frappe.db.get_value("Sales Invoice", old, "docstatus"), 2)
		self.assertFalse(frappe.db.get_value("Delivery Note", dn, "astrasun_invoice"))
		self.assertEqual(loading.change_requests(), [])

		frappe.set_user(self.loader)
		new = invoicing.invoice(dn)
		self.assertNotEqual(new["invoice"], old)
		self.assertEqual(frappe.db.get_value("Sales Invoice Item", {"parent": new["invoice"]}, "qty"), 8)
		self.assertEqual(invoicing.dispatch(dn)["status"], "Dispatched")

	def test_turned_down_change_leaves_load_and_bill_as_they_were(self):
		_, dn, old = self._billed(qty=10)
		self._ask(dn, 5)
		frappe.set_user(self.manager)
		done = loading.decide_change(dn, 0, "Bags are already on the truck")
		self.assertEqual(done["items"][0]["qty"], 10)
		self.assertEqual(frappe.db.get_value("Sales Invoice", old, "docstatus"), 1)
		self.assertEqual(frappe.db.get_value("Delivery Note", dn, "astrasun_invoice"), old)
		frappe.set_user(self.loader)
		self.assertEqual(invoicing.dispatch(dn)["status"], "Dispatched")

	def test_change_rules(self):
		_, dn, _inv = self._billed(qty=10)
		with self.assertRaises(loading.LoadingError):
			self._ask(dn, 8, " ")  # a reason is needed
		with self.assertRaises(loading.LoadingError):
			self._ask(dn, 11)  # more than the order asks for
		with self.assertRaises(loading.LoadingError):
			self._ask(dn, 0)  # nothing loaded: cancel the order instead
		with self.assertRaises(loading.LoadingError):
			self._ask(dn, 10)  # the same bags
		self._ask(dn, 9)
		with self.assertRaises(loading.LoadingError):
			self._ask(dn, 8)  # one change at a time
		frappe.set_user(self.loader)
		with self.assertRaises(frappe.PermissionError):
			loading.decide_change(dn, 1)  # the warehouse cannot approve its own change
		with self.assertRaises(frappe.PermissionError):
			loading.change_requests()
		frappe.set_user(self.rep)
		with self.assertRaises(frappe.PermissionError):
			loading.request_change(dn, [{"item_code": ITEM, "qty": 7}], "Because")

	def test_a_truck_that_left_cannot_be_changed(self):
		_, dn, _inv = self._billed()
		invoicing.dispatch(dn)
		with self.assertRaises(loading.LoadingError):
			self._ask(dn, 8)

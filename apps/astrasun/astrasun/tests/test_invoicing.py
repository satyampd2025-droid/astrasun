import frappe

from astrasun import invoicing, loading, orders
from astrasun.tests.helpers import ITEM, MillFixture, _user


class TestInvoicing(MillFixture):
	def setUp(self):
		super().setUp()
		self.loader = _user("loader@example.com", "Mill Warehouse")
		self.accounts = _user("accounts@example.com", "Mill Accounts")
		self.dispatcher = _user("dispatch@example.com", "Mill Dispatch")

	def _loaded(self, qty=10, loaded=None):
		order = self._order(self._customer(limit=10000000), qty=qty)
		frappe.set_user(self.manager)
		orders.approve(order["name"])
		frappe.set_user(self.loader)
		task = loading.start(order["name"])
		done = loading.mark_loaded(task["name"], "MP09AB1234", [{"item_code": ITEM, "qty": loaded or qty}])
		return order["name"], done["name"]

	def test_invoice_uses_loaded_bags_and_unlocks_dispatch(self):
		so, dn = self._loaded(qty=10, loaded=8)
		frappe.set_user(self.accounts)
		self.assertIn(dn, [t["name"] for t in invoicing.to_invoice()])
		view = invoicing.invoice(dn)
		self.assertEqual(view["invoice_total"], 8 * 1500 * 1.0 * (1 + self._gst(view["invoice"])))
		self.assertNotIn(dn, [t["name"] for t in invoicing.to_invoice()])
		frappe.set_user(self.dispatcher)
		self.assertIn(dn, [t["name"] for t in invoicing.to_dispatch()])
		out = invoicing.dispatch(dn)
		self.assertEqual(out["status"], "Dispatched")
		self.assertEqual(frappe.db.get_value("Delivery Note", dn, "docstatus"), 1)
		self.assertEqual(frappe.db.get_value("Sales Invoice", view["invoice"], "docstatus"), 1)

	def _gst(self, invoice):
		si = frappe.get_doc("Sales Invoice", invoice)
		return (si.grand_total - si.net_total) / si.net_total if si.net_total else 0

	def test_cannot_dispatch_without_invoice(self):
		_, dn = self._loaded()
		frappe.set_user(self.dispatcher)
		with self.assertRaises(invoicing.InvoicingError):
			invoicing.dispatch(dn)
		self.assertEqual(frappe.db.get_value("Delivery Note", dn, "docstatus"), 0)

	def test_warehouse_prints_the_bill_and_a_big_load_needs_no_eway_bill(self):
		"""The e-way bill is left to v2: no number is asked for, whatever the load is worth."""
		_, dn = self._loaded(qty=40)  # 40 x 1500 = 60,000
		frappe.set_user(self.loader)
		view = invoicing.invoice(dn)
		self.assertTrue(view["invoice"])
		self.assertNotIn("eway_bill_needed", view)
		self.assertEqual(invoicing.dispatch(dn)["status"], "Dispatched")  # the warehouse sends it too

	def test_cannot_invoice_twice_and_roles_enforced(self):
		_, dn = self._loaded()
		frappe.set_user(self.rep)
		with self.assertRaises(frappe.PermissionError):
			invoicing.invoice(dn)
		frappe.set_user(self.loader)
		invoicing.invoice(dn)
		with self.assertRaises(invoicing.InvoicingError):
			invoicing.invoice(dn)
		frappe.set_user(self.accounts)
		with self.assertRaises(frappe.PermissionError):
			invoicing.dispatch(dn)  # accounts bill, they do not send trucks

	def test_the_truck_leaves_without_anyone_typing_a_batch(self):
		# ERPNext skips its batch check while testing, so switch the test mode off to see what a real server does
		from astrasun.setup.install import setup_stock_settings

		setup_stock_settings()
		self.assertEqual(
			frappe.db.get_single_value("Stock Settings", "auto_create_serial_and_batch_bundle_for_outward"), 1
		)
		so, dn = self._loaded(qty=4)
		frappe.set_user(self.accounts)
		invoicing.invoice(dn)
		frappe.set_user(self.dispatcher)
		in_test, frappe.flags.in_test = frappe.flags.in_test, False
		try:
			out = invoicing.dispatch(dn)
		finally:
			frappe.flags.in_test = in_test
		self.assertEqual(out["status"], "Dispatched")

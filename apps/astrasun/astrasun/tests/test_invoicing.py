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

	def _real_server(self):
		"""ERPNext skips its batch check while testing; switch test mode off to see a real server."""
		self.addCleanup(setattr, frappe.flags, "in_test", frappe.flags.in_test)
		frappe.flags.in_test = False

	def test_the_warehouse_chooses_the_batch_and_the_truck_leaves(self):
		self._stock(20)
		order = self._order(self._customer(limit=10000000), qty=4)
		frappe.set_user(self.manager)
		orders.approve(order["name"])
		frappe.set_user(self.loader)
		task = loading.start(order["name"])
		listed = loading.batches(ITEM)
		self.assertTrue(listed["tracked"])
		batch = listed["batches"][0]
		self.assertGreaterEqual(batch["qty"], 20)
		dn = loading.mark_loaded(
			task["name"], "MP09AB1234", [{"item_code": ITEM, "qty": 4, "batch_no": batch["batch_no"]}]
		)["name"]
		self.assertEqual(
			loading._task(frappe.get_doc("Delivery Note", dn))["items"][0]["batch_no"], batch["batch_no"]
		)
		frappe.set_user(self.accounts)
		invoicing.invoice(dn)
		frappe.set_user(self.dispatcher)
		self._real_server()
		self.assertEqual(invoicing.dispatch(dn)["status"], "Dispatched")
		rows = frappe.get_all(
			"Delivery Note Item", filters={"parent": dn}, fields=["qty", "serial_and_batch_bundle"]
		)
		self.assertEqual(sum(r.qty for r in rows), 4)
		self.assertTrue(all(r.serial_and_batch_bundle for r in rows))

	def test_a_load_can_take_bags_from_two_batches_and_is_billed_whole(self):
		self._stock(3)
		self._stock(5)
		order = self._order(self._customer(limit=10000000), qty=6)
		frappe.set_user(self.manager)
		orders.approve(order["name"])
		frappe.set_user(self.loader)
		task = loading.start(order["name"])
		stock = sorted(loading.batches(ITEM)["batches"], key=lambda x: -x["qty"])
		self.assertGreaterEqual(len(stock), 2)
		b, a = stock[0], stock[1]  # four bags from the big batch, two from another
		dn = loading.mark_loaded(
			task["name"],
			"MP09AB1234",
			[
				{"item_code": ITEM, "qty": 2, "batch_no": a["batch_no"]},
				{"item_code": ITEM, "qty": 4, "batch_no": b["batch_no"]},
			],
		)["name"]
		self.assertEqual(len(frappe.get_doc("Delivery Note", dn).items), 2)
		view = invoicing.invoice(dn)
		self.assertEqual(sum(r.qty for r in frappe.get_doc("Sales Invoice", view["invoice"]).items), 6)

	def test_a_batch_without_enough_bags_is_refused(self):
		self._stock(3)
		order = self._order(self._customer(limit=10000000), qty=4)
		frappe.set_user(self.manager)
		orders.approve(order["name"])
		frappe.set_user(self.loader)
		task = loading.start(order["name"])
		stock = loading.batches(ITEM)["batches"]
		small = min(stock, key=lambda b: b["qty"])
		with self.assertRaises(loading.LoadingError):
			loading.mark_loaded(
				task["name"],
				"MP09AB1234",
				[
					{
						"item_code": ITEM,
						"qty": 4,
						"batch_no": small["batch_no"] if small["qty"] < 4 else "NOPE",
					}
				],
			)

	def test_the_truck_cannot_leave_with_no_batch_chosen(self):
		so, dn = self._loaded(qty=4)
		frappe.set_user(self.accounts)
		invoicing.invoice(dn)
		frappe.set_user(self.dispatcher)
		self._real_server()
		with self.assertRaises(invoicing.InvoicingError):
			invoicing.dispatch(dn)

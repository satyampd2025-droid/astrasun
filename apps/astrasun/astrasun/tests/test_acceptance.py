"""The 15-step MVP acceptance test from the PRD (section 38), end to end, as real users.

Each step carries its PRD number. Run with the rest of the suite.
"""

import frappe

from astrasun import (
	dashboard,
	delivery,
	invoicing,
	loading,
	milling,
	orders,
	packing,
	payments,
	reports,
	wheat,
)
from astrasun.setup.masters import bag_code
from astrasun.tests.helpers import ITEM, MillFixture, _user


class TestMVPAcceptance(MillFixture):
	def test_the_whole_mill_end_to_end(self):
		gate, qc = _user("gate@example.com", "Mill Gate"), _user("qc@example.com", "Mill QC")
		miller = _user("miller@example.com", "Mill Production")
		packer = _user("packer@example.com", "Mill Packing")
		loader = _user("loader@example.com", "Mill Warehouse")
		accounts = _user("accounts@example.com", "Mill Accounts")
		dispatcher = _user("dispatch@example.com", "Mill Dispatch")
		driver = _user("driver@example.com", "Mill Driver")
		if not frappe.db.exists("Supplier", "Test Mandi Trader"):
			frappe.get_doc(
				{"doctype": "Supplier", "supplier_name": "Test Mandi Trader", "supplier_group": "All Supplier Groups"}
			).insert()

		def stock(code):
			wh = frappe.db.get_value("Item Default", {"parent": code, "company": self.company}, "default_warehouse")
			return flt_(frappe.db.get_value("Bin", {"item_code": code, "warehouse": wh}, "actual_qty"))

		wheat0, atta0, fg0 = stock("WHEAT"), stock("ATTA-BULK"), stock("ATTA-10KG")
		# Empty bags arrive through purchasing (not part of the 15 steps)
		frappe.set_user("Administrator")
		entry = frappe.get_doc(
			{
				"doctype": "Stock Entry",
				"stock_entry_type": "Material Receipt",
				"company": self.company,
				"items": [
					{
						"item_code": bag_code("ATTA-BULK", 10),
						"qty": 500,
						"basic_rate": 5,
						"t_warehouse": f"Packaging Material - {self.abbr}",
					}
				],
			}
		).insert()
		entry.flags.change_reason = "Empty bags received"
		entry.submit()

		# 1. Wheat purchase with supplier, quantity, rate and lot: raw stock goes up
		frappe.set_user(gate)
		lot = wheat.gate_in("Test Mandi Trader", "MP04AB1234", 20000, 2600)["name"]
		wheat.weigh_in(lot, 28000)
		# 2. QC result entered and the lot released
		frappe.set_user(qc)
		self.assertEqual(wheat.check(lot, 12.5, 1, 1.5, "Release")["status"], "Released")
		frappe.set_user(gate)
		received = wheat.weigh_out(lot, 8000)
		self.assertEqual(received["status"], "Received")
		self.assertEqual(stock("WHEAT"), wheat0 + 20000)

		# 3. Production batch consumes wheat; bulk atta and by-products are recorded
		frappe.set_user(miller)
		batch = milling.record_batch("Morning", 10000, 7000, 1000, 500, 1400, 300)
		self.assertEqual(stock("WHEAT"), wheat0 + 10000)
		self.assertEqual(stock("ATTA-BULK"), atta0 + 7000)
		self.assertAlmostEqual(batch["extraction_pct"], 85)

		# 4. Packing batch: bulk atta goes down, finished goods go up
		frappe.set_user(packer)
		packing.pack("ATTA-10KG", 300)
		self.assertEqual(stock("ATTA-BULK"), atta0 + 7000 - 3000)
		self.assertEqual(stock("ATTA-10KG"), fg0 + 300)

		# 5. Sales user creates a customer order (list price 440 per 10 kg bag)
		frappe.set_user("Administrator")
		if not frappe.db.exists("Item Price", {"item_code": "ATTA-10KG", "selling": 1}):
			frappe.get_doc(
				{
					"doctype": "Item Price",
					"item_code": "ATTA-10KG",
					"price_list": "Standard Selling",
					"selling": 1,
					"price_list_rate": 440,
				}
			).insert()
		customer = self._customer(limit=1000000)
		frappe.set_user(self.rep)
		order = orders.create_order(customer, [{"item_code": "ATTA-10KG", "qty": 100, "rate": 400}])
		# 6. System checks stock, price threshold and credit
		self.assertFalse(order["stock_short"])
		self.assertFalse(order["credit_breach"])
		self.assertTrue(order["below_min_price"])  # list price is higher than 400
		# 7. Management approves; the approval is auditable
		# Below list price, so a manager is refused and the owner decides
		frappe.set_user(self.manager)
		with self.assertRaises(orders.CreditOverrideError):
			orders.approve(order["name"])
		frappe.set_user(self.owner)
		orders.approve(order["name"], "OK for this dealer")
		self.assertTrue(
			frappe.db.exists(
				"Critical Change Log", {"reference_name": order["name"], "action": "Approval", "user": self.owner}
			)
		)
		# 8. Warehouse gets the loading task and confirms what was actually loaded
		frappe.set_user(loader)
		self.assertIn(order["name"], [w["sales_order"] for w in loading.queue()["waiting"]])
		task = loading.start(order["name"])
		loading.mark_loaded(task["name"], "MP09AB1234", [{"item_code": "ATTA-10KG", "qty": 100}])
		# 10. Invoice generated from the approved transaction and stored (before dispatch, D5)
		frappe.set_user(accounts)
		view = invoicing.invoice(task["name"])
		self.assertEqual(frappe.db.get_value("Sales Invoice", view["invoice"], "docstatus"), 1)
		# 9. Dispatch recorded with vehicle data
		frappe.set_user(dispatcher)
		out = invoicing.dispatch(task["name"])
		self.assertEqual(out["vehicle_no"], "MP09AB1234")
		frappe.set_user(driver)
		delivery.deliver(task["name"], "Ramesh Sharma")

		# 11. Finished stock and customer receivable update correctly
		self.assertEqual(stock("ATTA-10KG"), fg0 + 200)
		invoice_total = frappe.db.get_value("Sales Invoice", view["invoice"], "grand_total")
		self.assertEqual(frappe.db.get_value("Sales Invoice", view["invoice"], "outstanding_amount"), invoice_total)
		owed = {d["customer"]: d["due"] for d in payments.dues()}
		self.assertEqual(owed[customer], invoice_total)
		payments.collect(customer, 10000, "Cash")
		self.assertEqual({d["customer"]: d["due"] for d in payments.dues()}[customer], invoice_total - 10000)

		# 12. Owner dashboard shows the transaction and the KPI changes
		frappe.set_user(self.owner)
		day = dashboard.today()
		self.assertGreaterEqual(day["invoiced"], invoice_total)
		self.assertGreaterEqual(day["collected"], 10000)
		self.assertGreaterEqual(day["wheat_ground_kg"], 10000)

		# 13. The monthly stock report reconciles with the ledger movements
		report = reports.stock_statement()
		self.assertTrue(report["reconciled"])
		rows = {r["item_code"]: r for r in report["items"]}
		self.assertGreaterEqual(rows["WHEAT"]["received"], 20000)
		self.assertGreaterEqual(rows["ATTA-10KG"]["issued"], 100)

		# 14. Management P&L from recorded transactions
		pnl = reports.profit_and_loss()
		self.assertGreaterEqual(pnl["sales"], invoice_total / 1.05 - 1)
		self.assertGreater(pnl["cost_of_goods"], 0)
		self.assertAlmostEqual(pnl["gross_profit"], pnl["sales"] - pnl["cost_of_goods"], places=2)

		# 15. Every critical change traces through the audit log
		stock_move = frappe.get_all("Critical Change Log", filters={"reference_name": order["name"]})
		self.assertTrue(stock_move)
		with self.assertRaises((frappe.ValidationError, frappe.PermissionError)):
			frappe.get_doc("Critical Change Log", stock_move[0].name).delete()


def flt_(v):
	return float(v or 0)

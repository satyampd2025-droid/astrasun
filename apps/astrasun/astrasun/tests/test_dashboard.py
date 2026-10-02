import frappe

from astrasun import dashboard, delivery, milling, payments, wheat
from astrasun.tests.helpers import MillFixture, _user


class TestDashboard(MillFixture):
	def setUp(self):
		super().setUp()
		self.driver = _user("driver@example.com", "Mill Driver")

	def test_owner_sees_the_day(self):
		customer, _dn, inv = self.make_dispatched(qty=10)
		frappe.set_user(self.owner)
		before = dashboard.today()
		self.assertGreater(before["invoiced"], 0)
		self.assertGreater(before["sales_booked"], 0)
		due = frappe.db.get_value("Sales Invoice", inv, "outstanding_amount")
		frappe.set_user(self.driver)
		payments.collect(customer, 1000, "Cash")
		frappe.set_user(self.owner)
		after = dashboard.today()
		self.assertEqual(after["collected"], before["collected"] + 1000)
		self.assertEqual(after["dues_total"], before["dues_total"] - 1000)
		self.assertEqual(after["ageing"]["0-30"], before["ageing"]["0-30"] - 1000)
		self.assertGreaterEqual(due, 1000)

	def test_alerts_collect_weight_yield_and_downtime(self):
		gate, qc = _user("gate@example.com", "Mill Gate"), _user("qc@example.com", "Mill QC")
		if not frappe.db.exists("Supplier", "Test Mandi Trader"):
			frappe.get_doc(
				{"doctype": "Supplier", "supplier_name": "Test Mandi Trader", "supplier_group": "All Supplier Groups"}
			).insert()
		frappe.set_user(gate)
		lot = wheat.gate_in("Test Mandi Trader", "MP1", 20000, 2600)["name"]
		wheat.weigh_in(lot, 28000)
		frappe.set_user(qc)
		wheat.check(lot, 12, 1, 1, "Release")
		frappe.set_user(gate)
		wheat.weigh_out(lot, 8500)  # 19,500 vs 20,000
		miller = _user("miller@example.com", "Mill Production")
		frappe.set_user(self.manager)
		self._receipt_wheat()
		frappe.set_user(miller)
		milling.record_batch("Night", 1000, 600, 80, 40, 140)
		milling.report_downtime("Roller mill 2", 90, "Belt broke")
		frappe.set_user(self.owner)
		kinds = [a["kind"] for a in dashboard.today()["alerts"]]
		for kind in ("weight", "yield", "downtime"):
			self.assertIn(kind, kinds)

	def _receipt_wheat(self):
		user, _ = frappe.session.user, frappe.set_user("Administrator")
		entry = frappe.get_doc(
			{
				"doctype": "Stock Entry",
				"stock_entry_type": "Material Receipt",
				"company": self.company,
				"items": [
					{"item_code": "WHEAT", "qty": 5000, "basic_rate": 26, "t_warehouse": f"Raw Wheat - {self.abbr}"}
				],
			}
		).insert()
		entry.flags.change_reason = "Opening wheat for tests"
		entry.submit()
		frappe.set_user(user)

	def test_only_owner_and_manager(self):
		frappe.set_user(self.rep)
		with self.assertRaises(frappe.PermissionError):
			dashboard.today()
		frappe.set_user(self.manager)
		self.assertIn("alerts", dashboard.today())

import frappe

from astrasun import milling
from astrasun.tests.helpers import MillFixture, _user

WHEAT_WH = "Raw Wheat"


class TestMilling(MillFixture):
	def setUp(self):
		super().setUp()
		self.miller = _user("miller@example.com", "Mill Production")
		self._wheat(10000)
		frappe.set_user(self.miller)

	def _wheat(self, qty):
		wh = f"{WHEAT_WH} - {self.abbr}"
		entry = frappe.get_doc(
			{
				"doctype": "Stock Entry",
				"stock_entry_type": "Material Receipt",
				"company": self.company,
				"items": [{"item_code": "WHEAT", "qty": qty, "basic_rate": 26, "t_warehouse": wh}],
			}
		).insert()
		entry.flags.change_reason = "Opening wheat for tests"
		entry.submit()

	def test_batch_moves_wheat_out_and_flour_in(self):
		before = milling.wheat_available()
		b = milling.record_batch("Morning", 1000, 700, 100, 50, 140, 30)
		self.assertAlmostEqual(b["extraction_pct"], 85)
		self.assertEqual(b["loss_kg"], 10)
		self.assertFalse(b["low_yield"])
		self.assertEqual(milling.wheat_available(), before - 1000)
		entry = frappe.db.get_value("Milling Batch", b["name"], "stock_entry")
		self.assertEqual(frappe.db.get_value("Stock Entry", entry, "docstatus"), 1)
		atta = frappe.db.get_value("Stock Entry Detail", {"parent": entry, "item_code": "ATTA-BULK"}, "qty")
		self.assertEqual(atta, 700)
		self.assertEqual([r["name"] for r in milling.recent()][0], b["name"])

	def test_low_yield_and_high_loss_are_flagged(self):
		self.assertTrue(milling.record_batch("Night", 1000, 600, 80, 40, 140)["low_yield"])  # 72% flour
		self.assertTrue(milling.record_batch("Night", 1000, 700, 100, 50, 100)["low_yield"])  # 5% loss

	def test_bad_numbers_are_refused(self):
		for args in (
			("Day", 1000, 700, 100, 50, 140),
			("Morning", 0, 1, 1, 1, 1),
			("Morning", 1000, 0, 0, 0, 0),
			("Morning", 1000, 900, 200, 50, 140),
			("Morning", 99999, 700, 100, 50, 140),
			("Morning", 1000, -1, 100, 50, 140),
		):
			with self.assertRaises(milling.MillingError):
				milling.record_batch(*args)

	def test_downtime_and_roles(self):
		d = milling.report_downtime("Roller mill 2", 45, "Belt broke")
		self.assertEqual(d["minutes"], 45)
		with self.assertRaises(milling.MillingError):
			milling.report_downtime("", 0, "")
		frappe.set_user(self.rep)
		with self.assertRaises(frappe.PermissionError):
			milling.record_batch("Morning", 1000, 700, 100, 50, 140)

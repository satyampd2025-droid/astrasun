import frappe

from astrasun import milling, packing
from astrasun.tests.helpers import MillFixture, _user
from astrasun.setup.masters import bag_code


class TestPacking(MillFixture):
	def setUp(self):
		super().setUp()
		self.packer = _user("packer@example.com", "Mill Packing")
		self._receipt("ATTA-BULK", 1000, "Bulk Flour", 30)
		self._receipt(bag_code("ATTA-BULK", 10), 50, "Packaging Material", 5)

	def _receipt(self, code, qty, warehouse, rate):
		entry = frappe.get_doc(
			{
				"doctype": "Stock Entry",
				"stock_entry_type": "Material Receipt",
				"company": self.company,
				"items": [
					{"item_code": code, "qty": qty, "basic_rate": rate, "t_warehouse": f"{warehouse} - {self.abbr}"}
				],
			}
		).insert()
		entry.flags.change_reason = "Opening stock for tests"
		entry.submit()

	def test_packing_uses_bulk_and_bags_and_adds_packed_stock(self):
		frappe.set_user(self.packer)
		sku = {s["item_code"]: s for s in packing.skus()}["ATTA-10KG"]
		before = sku["packed_bags"]
		done = packing.pack("ATTA-10KG", 40)
		self.assertEqual(done["bulk_used_kg"], 400)
		self.assertEqual(done["packed_bags"], before + 40)
		after = {s["item_code"]: s for s in packing.skus()}["ATTA-10KG"]
		self.assertEqual(after["bulk_kg"], sku["bulk_kg"] - 400)
		self.assertEqual(after["empty_bags"], sku["empty_bags"] - 40)

	def test_cannot_pack_more_than_flour_or_bags(self):
		frappe.set_user(self.packer)
		with self.assertRaises(packing.PackingError):
			packing.pack("ATTA-10KG", 51)  # only 50 empty bags
		with self.assertRaises(packing.PackingError):
			packing.pack("ATTA-10KG", 0)
		with self.assertRaises(packing.PackingError):
			packing.pack("ATTA-10KG", 2.5)
		with self.assertRaises(packing.PackingError):
			packing.pack("ATTA-7KG", 1)
		frappe.set_user(self.rep)
		with self.assertRaises(frappe.PermissionError):
			packing.pack("ATTA-10KG", 1)

	def test_stock_view_for_phones(self):
		frappe.set_user(self.rep)
		rows = {r["item_code"]: r for r in packing.stock()}
		self.assertEqual(rows["WHEAT"]["kind"], "Raw")
		self.assertGreaterEqual(rows["ATTA-BULK"]["qty"], 1000)
		self.assertEqual(rows["ATTA-10KG"]["unit"], "bags")

import frappe
from frappe.tests.utils import FrappeTestCase

from astrasun.setup.masters import PACK_SIZES, WAREHOUSES, bag_code, setup_mill, sku_code
from astrasun.setup.roles import ROLE_PROFILES


class TestSetup(FrappeTestCase):
	def setUp(self):
		self.company = (
			frappe.defaults.get_global_default("company") or frappe.get_all("Company", pluck="name")[0]
		)
		self.abbr = frappe.get_cached_value("Company", self.company, "abbr")

	def test_role_profiles(self):
		for name in ROLE_PROFILES:
			roles = {r.role for r in frappe.get_doc("Role Profile", name).roles}
			self.assertIn(name, roles)
		self.assertIn("Sales User", {r.role for r in frappe.get_doc("Role Profile", "Mill Sales").roles})

	def test_warehouses(self):
		for warehouse in WAREHOUSES:
			self.assertTrue(frappe.db.exists("Warehouse", f"{warehouse} - {self.abbr}"))

	def test_skus_and_packing_boms(self):
		for bulk, sizes in PACK_SIZES.items():
			for kg in sizes:
				sku = sku_code(bulk, kg)
				self.assertEqual(frappe.db.get_value("Item", sku, "weight_per_unit"), kg)
				bom = frappe.get_doc("BOM", frappe.db.get_value("BOM", {"item": sku, "is_default": 1}))
				self.assertEqual(
					{(i.item_code, i.qty) for i in bom.items}, {(bulk, kg), (bag_code(bulk, kg), 1)}
				)

	def test_milling_bom_balances(self):
		bom = frappe.get_doc("BOM", frappe.db.get_value("BOM", {"item": "ATTA-BULK", "is_default": 1}))
		wheat = sum(i.qty for i in bom.items)
		outputs = bom.quantity + sum(s.stock_qty for s in bom.scrap_items)
		self.assertEqual(wheat, 1000)
		self.assertLessEqual(outputs, wheat)
		self.assertGreater(outputs / wheat, 0.95)

	def test_setup_is_rerunnable(self):
		count = frappe.db.count("Item")
		setup_mill(self.company)
		self.assertEqual(frappe.db.count("Item"), count)

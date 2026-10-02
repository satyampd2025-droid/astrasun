import frappe
from frappe.tests.utils import FrappeTestCase

from astrasun.setup.masters import PACK_SIZES, WAREHOUSES, bag_code, setup_mill, sku_code
from astrasun.setup.roles import ROLE_PROFILES, sync_users


class TestSetup(FrappeTestCase):
	def setUp(self):
		self.company = (
			frappe.defaults.get_global_default("company") or frappe.get_all("Company", pluck="name")[0]
		)
		self.abbr = frappe.get_cached_value("Company", self.company, "abbr")

	def _account(self, email, *roles):
		"""A user made the way the back-office form allows: roles ticked one by one, no Role Profile."""
		user = frappe.get_doc(
			{"doctype": "User", "email": email, "first_name": email.split("@")[0], "send_welcome_email": 0}
		)
		for role in roles:
			user.append("roles", {"role": role})
		return user.insert(ignore_permissions=True)

	def test_role_profiles(self):
		for name in ROLE_PROFILES:
			roles = {r.role for r in frappe.get_doc("Role Profile", name).roles}
			self.assertIn(name, roles)
		self.assertIn("Sales User", {r.role for r in frappe.get_doc("Role Profile", "Mill Sales").roles})

	def test_mill_job_brings_its_standard_roles(self):
		"""Ticking only the mill job is enough: the roles ERPNext checks for come with it."""
		user = self._account("job-only@example.com", "Mill Sales")
		self.assertIn("Sales User", {r.role for r in user.roles})
		self.assertTrue(frappe.has_permission("Sales Order", "create", user=user.name))

	def test_no_job_no_extra_roles(self):
		user = self._account("no-job@example.com", "Sales User")
		self.assertEqual({r.role for r in user.roles}, {"Sales User"})

	def test_accounts_made_before_the_hook_are_repaired(self):
		user = self._account("older-account@example.com", "Mill Warehouse")
		frappe.db.delete("Has Role", {"parent": user.name, "role": "Stock User"})
		self.assertNotIn("Stock User", {r.role for r in frappe.get_doc("User", user.name).roles})
		sync_users()
		self.assertIn("Stock User", {r.role for r in frappe.get_doc("User", user.name).roles})

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

import frappe

from astrasun import wheat
from astrasun.tests.helpers import MillFixture, _user


class TestWheat(MillFixture):
	def setUp(self):
		super().setUp()
		self.gate = _user("gate@example.com", "Mill Gate")
		self.qc = _user("qc@example.com", "Mill QC")
		self.supplier = self._supplier()

	def _supplier(self):
		if not frappe.db.exists("Supplier", "Test Mandi Trader"):
			frappe.get_doc(
				{"doctype": "Supplier", "supplier_name": "Test Mandi Trader", "supplier_group": "All Supplier Groups"}
			).insert()
		return "Test Mandi Trader"

	def _truck(self, party=20000):
		frappe.set_user(self.gate)
		lot = wheat.gate_in(self.supplier, "mp 04 ab 9999", party, 2600)
		self.assertEqual(lot["vehicle_no"], "MP 04 AB 9999")
		return lot["name"]

	def _released(self, party=20000, gross=28000):
		name = self._truck(party)
		wheat.weigh_in(name, gross)
		frappe.set_user(self.qc)
		wheat.check(name, 12.5, 1.0, 2.0, "Release")
		frappe.set_user(self.gate)
		return name

	def test_good_truck_goes_to_stock_with_net_weight(self):
		name = self._released()
		lot = wheat.weigh_out(name, 8000)  # net 20,000 kg = slip
		self.assertEqual(lot["status"], "Received")
		self.assertEqual(lot["net_kg"], 20000)
		self.assertFalse(lot["weight_alert"])
		qty = frappe.db.get_value("Purchase Receipt Item", {"parent": lot["purchase_receipt"]}, "qty")
		self.assertEqual(qty, 20000)
		self.assertEqual(frappe.db.get_value("Purchase Receipt", lot["purchase_receipt"], "docstatus"), 1)
		self.assertNotIn(name, [t["name"] for t in wheat.trucks()])

	def test_weight_gap_raises_alert(self):
		name = self._released()
		lot = wheat.weigh_out(name, 8300)  # net 19,700: 1.5% short of the slip
		self.assertTrue(lot["weight_alert"])
		self.assertEqual(lot["weight_gap_kg"], -300)

	def test_lab_cannot_release_bad_wheat_but_manager_can_with_reason(self):
		name = self._truck()
		wheat.weigh_in(name, 28000)
		frappe.set_user(self.qc)
		with self.assertRaises(frappe.PermissionError):
			wheat.check(name, 16, 1, 1, "Release")
		wheat.check(name, 16, 1, 1, "Hold", "Too wet, dry it")
		frappe.set_user(self.manager)
		with self.assertRaises(wheat.WheatError):
			wheat.check(name, 16, 1, 1, "Release")  # needs a reason
		self.assertEqual(wheat.check(name, 16, 1, 1, "Release", "Dried, retested")["status"], "Released")

	def test_rejected_or_unchecked_truck_cannot_unload(self):
		name = self._truck()
		frappe.set_user(self.gate)
		with self.assertRaises(wheat.WheatError):
			wheat.weigh_out(name, 8000)  # not weighed in
		wheat.weigh_in(name, 28000)
		with self.assertRaises(wheat.WheatError):
			wheat.weigh_out(name, 8000)  # not released
		frappe.set_user(self.qc)
		wheat.check(name, 12, 1, 1, "Reject", "Musty smell")
		frappe.set_user(self.gate)
		with self.assertRaises(wheat.WheatError):
			wheat.weigh_out(name, 8000)

	def test_input_checks_and_roles(self):
		frappe.set_user(self.gate)
		with self.assertRaises(wheat.WheatError):
			wheat.gate_in(self.supplier, " ", 100, 2600)
		with self.assertRaises(wheat.WheatError):
			wheat.gate_in(self.supplier, "MP1", 0, 2600)
		frappe.set_user(self.rep)
		with self.assertRaises(frappe.PermissionError):
			wheat.trucks()
		name = self._truck()
		wheat.weigh_in(name, 28000)
		with self.assertRaises(frappe.PermissionError):
			wheat.check(name, 12, 1, 1, "Release")  # gate cannot do the lab's job

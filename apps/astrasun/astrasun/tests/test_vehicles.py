import frappe

from astrasun import delivery, loading, orders, vehicles
from astrasun.tests.helpers import ITEM, MillFixture, _user


class TestVehicles(MillFixture):
	def setUp(self):
		super().setUp()
		self.loader = _user("loader@example.com", "Mill Warehouse")
		self.driver = "driver@example.com"
		self.other_driver = _user("driver2@example.com", "Mill Driver")

	def _on_vehicle(self, plate="MP09AB1234", qty=10):
		"""An approved order loaded onto `plate`. Returns the loading task."""
		order = self._order(self._customer(limit=10000000), qty=qty)
		frappe.set_user(self.manager)
		orders.approve(order["name"])
		frappe.set_user(self.loader)
		task = loading.start(order["name"])
		return loading.mark_loaded(task["name"], plate, [{"item_code": ITEM, "qty": qty}])

	def test_owner_adds_a_vehicle_with_its_driver(self):
		frappe.set_user(self.owner)
		row = vehicles.save("mp 09-cd 5678", "Suresh Kumar", "9811111111", self.driver)
		self.assertEqual(row["vehicle_no"], "MP09CD5678")
		self.assertEqual(row["driver_user"], self.driver)
		# Saving it again with the same number changes it rather than adding a second one
		vehicles.save("MP09CD5678", "Suresh K", None, None, enabled=0)
		self.assertEqual(frappe.db.count("Mill Vehicle", {"vehicle_no": "MP09CD5678"}), 1)
		self.assertEqual(frappe.db.get_value("Mill Vehicle", "MP09CD5678", "driver_name"), "Suresh K")

	def test_vehicle_rules(self):
		frappe.set_user(self.owner)
		with self.assertRaises(vehicles.VehicleError):
			vehicles.save(" ", "Someone")
		with self.assertRaises(vehicles.VehicleError):
			vehicles.save("MP09CD5678", " ")
		with self.assertRaises(vehicles.VehicleError):
			vehicles.save("MP09CD5678", "Someone", None, "nobody@example.com")
		with self.assertRaises(vehicles.VehicleError):
			vehicles.save("MP09CD5678", "Someone", None, self.rep)  # a sales rep is not a driver
		frappe.set_user(self.rep)
		with self.assertRaises(frappe.PermissionError):
			vehicles.save("MP09CD5678", "Someone")

	def test_warehouse_picks_only_from_available_vehicles(self):
		frappe.set_user(self.owner)
		vehicles.save("MP09CD5678", "Suresh Kumar", None, None, enabled=0)
		frappe.set_user(self.loader)
		listed = [v["vehicle_no"] for v in vehicles.vehicles()]
		self.assertIn("MP09AB1234", listed)
		self.assertNotIn("MP09CD5678", listed)
		frappe.set_user(self.owner)
		self.assertIn("MP09CD5678", [v["vehicle_no"] for v in vehicles.vehicles(all=1)])
		with self.assertRaises(loading.LoadingError):
			self._on_vehicle("MP09CD5678")  # switched off
		with self.assertRaises(loading.LoadingError):
			self._on_vehicle("MP00ZZ0000")  # never listed

	def test_picking_the_vehicle_brings_its_driver(self):
		task = self._on_vehicle("mp09 ab 1234")
		self.assertEqual(task["vehicle_no"], "MP09AB1234")
		self.assertEqual(task["driver_name"], "Ramesh Driver")
		self.assertEqual(task["driver_phone"], "9800000001")
		self.assertEqual(frappe.db.get_value("Delivery Note", task["name"], "astrasun_driver_user"), self.driver)

	def test_driver_sees_the_orders_on_their_vehicle_with_details(self):
		task = self._on_vehicle(qty=10)
		frappe.set_user(self.driver)
		mine = {t["name"]: t for t in delivery.my_deliveries()}
		self.assertIn(task["name"], mine)  # already while the truck is being loaded
		view = mine[task["name"]]
		self.assertEqual(view["customer_name"], task["customer_name"])
		self.assertEqual(view["items"][0]["qty"], 10)
		self.assertEqual(view["items"][0]["rate"], 1500)
		self.assertEqual(view["items"][0]["amount"], 15000)
		self.assertIn("address", view)
		self.assertIn("customer_phone", view)
		self.assertEqual(view["vehicle_no"], "MP09AB1234")
		# Another driver sees nothing of it, and cannot mark it delivered
		frappe.set_user(self.other_driver)
		self.assertNotIn(task["name"], [t["name"] for t in delivery.my_deliveries()])
		with self.assertRaises(frappe.PermissionError):
			delivery.deliver(task["name"], "Someone")

	def test_owner_and_dispatch_see_every_vehicle(self):
		task = self._on_vehicle()
		frappe.set_user(self.owner)
		self.assertIn(task["name"], [t["name"] for t in delivery.my_deliveries()])

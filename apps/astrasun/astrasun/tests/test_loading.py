import frappe

from astrasun import loading, orders
from astrasun.tests.helpers import ITEM, MillFixture


class TestLoading(MillFixture):
	def _approved(self, qty=10):
		order = self._order(self._customer(limit=1000000), qty=qty)
		frappe.set_user(self.manager)
		orders.approve(order["name"])
		return order["name"]

	def _loader(self):
		frappe.set_user(self.loader)

	def setUp(self):
		super().setUp()
		from astrasun.tests.helpers import _user

		self.loader = _user("loader@example.com", "Mill Warehouse")

	def test_approved_order_waits_then_loads(self):
		so = self._approved()
		self._loader()
		self.assertIn(so, [w["sales_order"] for w in loading.queue()["waiting"]])
		task = loading.start(so, "mp 09 ab 1234")
		self.assertEqual(task["status"], "Loading")
		self.assertEqual(task["vehicle_no"], "MP09AB1234")  # the vehicle as the owner listed it
		queue = loading.queue()
		self.assertNotIn(so, [w["sales_order"] for w in queue["waiting"]])
		self.assertIn(task["name"], [t["name"] for t in queue["loading"]])
		done = loading.mark_loaded(task["name"], "MP09AB1234", [{"item_code": ITEM, "qty": 8}])
		self.assertEqual(done["status"], "Loaded")
		self.assertEqual(done["items"][0]["qty"], 8)
		self.assertEqual(done["loaded_by"], self.loader)
		# Still a draft: dispatch waits for the invoice
		self.assertEqual(frappe.db.get_value("Delivery Note", task["name"], "docstatus"), 0)

	def test_cannot_load_more_than_ordered(self):
		so = self._approved()
		self._loader()
		task = loading.start(so)
		with self.assertRaises(loading.LoadingError):
			loading.mark_loaded(task["name"], "MP09AB1234", [{"item_code": ITEM, "qty": 11}])

	def test_vehicle_number_required(self):
		so = self._approved()
		self._loader()
		task = loading.start(so)
		with self.assertRaises(loading.LoadingError):
			loading.mark_loaded(task["name"], " ")

	def test_unapproved_order_cannot_load_and_sales_cannot_load(self):
		order = self._order(self._customer(limit=1000000))
		self._loader()
		self.assertNotIn(order["name"], [w["sales_order"] for w in loading.queue()["waiting"]])
		with self.assertRaises(loading.LoadingError):
			loading.start(order["name"])
		frappe.set_user(self.rep)
		with self.assertRaises(frappe.PermissionError):
			loading.queue()

	def test_one_loading_task_per_order(self):
		so = self._approved()
		self._loader()
		loading.start(so)
		with self.assertRaises(loading.LoadingError):
			loading.start(so)

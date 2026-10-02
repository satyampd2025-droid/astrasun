import frappe
from frappe.tests.utils import FrappeTestCase

from astrasun.api import me, set_language


class TestApi(FrappeTestCase):
	def setUp(self):
		email = "loader@example.com"
		if not frappe.db.exists("User", email):
			frappe.get_doc(
				{
					"doctype": "User",
					"email": email,
					"first_name": "Ramesh",
					"send_welcome_email": 0,
					"role_profile_name": "Mill Warehouse",
				}
			).insert(ignore_permissions=True)
		self.user = email

	def tearDown(self):
		frappe.set_user("Administrator")

	def test_me_returns_mill_roles(self):
		frappe.set_user(self.user)
		info = me()
		self.assertEqual(info["full_name"], "Ramesh")
		self.assertEqual(info["mill_roles"], ["Mill Warehouse"])

	def test_administrator_gets_owner_home(self):
		self.assertEqual(me()["mill_roles"], ["Mill Owner"])

	def test_set_language(self):
		frappe.set_user(self.user)
		set_language("hi")
		self.assertEqual(me()["language"], "hi")
		self.assertRaises(frappe.ValidationError, set_language, "fr")

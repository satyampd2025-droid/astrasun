import frappe

from astrasun import delivery, payments
from astrasun.tests.helpers import MillFixture, _user


class TestDeliveryAndPayments(MillFixture):
	def setUp(self):
		super().setUp()
		self.driver = _user("driver@example.com", "Mill Driver")

	def test_driver_records_delivery_proof(self):
		_, dn, _inv = self.make_dispatched()
		frappe.set_user(self.driver)
		self.assertIn(dn, [t["name"] for t in delivery.my_deliveries()])
		with self.assertRaises(frappe.ValidationError):
			delivery.deliver(dn, " ")
		done = delivery.deliver(dn, "Ramesh Sharma", "Delivered at shop")
		self.assertEqual(done["status"], "Delivered")
		self.assertEqual(frappe.db.get_value("Delivery Note", dn, "astrasun_received_by"), "Ramesh Sharma")
		self.assertNotIn(dn, [t["name"] for t in delivery.my_deliveries()])
		with self.assertRaises(frappe.ValidationError):
			delivery.deliver(dn, "Someone else")

	def test_payment_goes_to_oldest_invoice_first(self):
		customer, _dn1, inv1 = self.make_dispatched(qty=10)  # 15,000 + GST
		_, _dn2, inv2 = self.make_dispatched(qty=20, customer=customer)
		total1 = frappe.db.get_value("Sales Invoice", inv1, "outstanding_amount")
		frappe.set_user(self.driver)
		listed = payments.dues()
		self.assertEqual(listed[0]["customer"], customer)
		self.assertEqual([i["name"] for i in listed[0]["invoices"]], [inv1, inv2])
		result = payments.collect(customer, total1 + 1000, "Cash")
		self.assertEqual([m["invoice"] for m in result["matched"]], [inv1, inv2])
		self.assertEqual(frappe.db.get_value("Sales Invoice", inv1, "outstanding_amount"), 0)
		self.assertEqual(frappe.db.get_value("Sales Invoice", inv2, "outstanding_amount"), 
			frappe.db.get_value("Sales Invoice", inv2, "grand_total") - 1000)
		self.assertEqual(result["still_due"], frappe.db.get_value("Sales Invoice", inv2, "outstanding_amount"))

	def test_payment_rules(self):
		customer, _dn, inv = self.make_dispatched()
		due = frappe.db.get_value("Sales Invoice", inv, "outstanding_amount")
		frappe.set_user(self.driver)
		with self.assertRaises(payments.PaymentError):
			payments.collect(customer, 0)
		with self.assertRaises(payments.PaymentError):
			payments.collect(customer, due + 1)
		with self.assertRaises(payments.PaymentError):
			payments.collect(customer, 100, "Bank")  # needs UTR
		payments.collect(customer, due, "Bank", "UTR123456")
		with self.assertRaises(payments.PaymentError):
			payments.collect(customer, 1)
		frappe.set_user(_user("loader@example.com", "Mill Warehouse"))
		with self.assertRaises(frappe.PermissionError):
			payments.dues()

	def test_rep_sees_dues_but_cannot_collect(self):
		"""PRD: a sales rep checks customer dues before taking an order; only collectors receive money."""
		customer, _dn, _inv = self.make_dispatched()
		frappe.set_user(self.rep)
		self.assertIn(customer, [d["customer"] for d in payments.dues()])
		with self.assertRaises(frappe.PermissionError):
			payments.collect(customer, 1000)

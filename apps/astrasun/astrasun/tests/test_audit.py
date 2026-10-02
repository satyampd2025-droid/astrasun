import frappe
from frappe.tests.utils import FrappeTestCase

from astrasun.audit import REASON_FIELD, ReasonRequiredError


def _company():
	return frappe.defaults.get_global_default("company") or frappe.get_all("Company", pluck="name")[0]


def _logs(doc):
	return frappe.get_all(
		"Critical Change Log",
		filters={"reference_doctype": doc.doctype, "reference_name": doc.name},
		fields=["action", "field_name", "old_value", "new_value", "reason", "user"],
		order_by="creation asc",
	)


class TestAudit(FrappeTestCase):
	def setUp(self):
		self.company = _company()
		self.abbr = frappe.get_cached_value("Company", self.company, "abbr")

	def _item_price(self, rate=1500):
		price_list = frappe.get_doc(
			{"doctype": "Price List", "price_list_name": frappe.generate_hash(length=10), "selling": 1}
		).insert()
		return frappe.get_doc(
			{
				"doctype": "Item Price",
				"item_code": "ATTA-50KG",
				"price_list": price_list.name,
				"price_list_rate": rate,
				"uom": "Bag",
			}
		).insert()

	def test_new_record_needs_no_reason(self):
		price = self._item_price()
		self.assertEqual(_logs(price), [])

	def test_price_change_without_reason_is_refused(self):
		price = self._item_price()
		price.price_list_rate = 1400
		self.assertRaises(ReasonRequiredError, price.save)

	def test_price_change_with_reason_is_logged(self):
		price = self._item_price()
		price.price_list_rate = 1450
		price.set(REASON_FIELD, "Wheat rate dropped")
		price.save()

		(log,) = _logs(price)
		self.assertEqual(log.action, "Update")
		self.assertEqual(log.field_name, "price_list_rate")
		self.assertEqual(float(log.old_value), 1500)
		self.assertEqual(float(log.new_value), 1450)
		self.assertEqual(log.reason, "Wheat rate dropped")
		self.assertEqual(log.user, frappe.session.user)
		# The reason is not kept for the next change
		self.assertFalse(frappe.db.get_value("Item Price", price.name, REASON_FIELD))
		price.reload()
		price.price_list_rate = 1300
		self.assertRaises(ReasonRequiredError, price.save)

	def test_reason_from_code(self):
		price = self._item_price()
		price.price_list_rate = 1550
		price.flags.change_reason = "Daily price update"
		price.save()
		self.assertEqual(_logs(price)[0].reason, "Daily price update")

	def test_non_critical_change_needs_no_reason(self):
		price = self._item_price()
		price.note = "Festival rate"
		price.save()
		self.assertEqual(_logs(price), [])

	def test_credit_limit_change_is_logged(self):
		customer = frappe.get_doc(
			{
				"doctype": "Customer",
				"customer_name": frappe.generate_hash(length=8),
				"customer_type": "Company",
				"customer_group": "Retailer",
			}
		).insert()
		customer.reload()
		customer.append("credit_limits", {"company": self.company, "credit_limit": 50000})
		self.assertRaises(ReasonRequiredError, customer.save)

		customer.reload()
		customer.append("credit_limits", {"company": self.company, "credit_limit": 50000})
		customer.flags.change_reason = "Approved by owner"
		customer.save()
		(log,) = _logs(customer)
		self.assertEqual(log.field_name, "credit_limits")
		self.assertIn("50000", log.new_value)

	def _wheat_receipt(self):
		return frappe.get_doc(
			{
				"doctype": "Stock Entry",
				"stock_entry_type": "Material Receipt",
				"company": self.company,
				"items": [
					{
						"item_code": "WHEAT",
						"qty": 100,
						"basic_rate": 25,
						"t_warehouse": f"Raw Wheat - {self.abbr}",
					}
				],
			}
		).insert()

	def test_stock_adjustment_needs_reason_at_submit(self):
		entry = self._wheat_receipt()
		self.assertRaises(ReasonRequiredError, entry.submit)

		entry.reload()
		entry.flags.change_reason = "Opening stock count"
		entry.submit()
		(log,) = _logs(entry)
		self.assertEqual(log.action, "Stock Adjustment")
		self.assertEqual(log.reason, "Opening stock count")

	def test_cancel_needs_reason(self):
		entry = self._wheat_receipt()
		entry.flags.change_reason = "Opening stock count"
		entry.submit()

		entry.reload()
		self.assertRaises(ReasonRequiredError, entry.cancel)

		entry.reload()
		entry.set(REASON_FIELD, "Entered twice")
		entry.save()  # update after submit, as the web form does
		entry.reload()
		entry.cancel()
		actions = [(log.action, log.reason) for log in _logs(entry)]
		self.assertEqual(actions, [("Stock Adjustment", "Opening stock count"), ("Cancel", "Entered twice")])

	def test_log_is_append_only(self):
		price = self._item_price()
		price.price_list_rate = 1600
		price.flags.change_reason = "Test"
		price.save()
		log = frappe.get_last_doc("Critical Change Log", filters={"reference_name": price.name})
		log.reason = "Changed"
		self.assertRaises(frappe.ValidationError, log.save)
		self.assertRaises(frappe.ValidationError, log.delete)

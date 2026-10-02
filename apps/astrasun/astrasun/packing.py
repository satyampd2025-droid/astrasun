"""Packing: bulk flour and empty bags become packed bags ready to sell.

One packing batch uses bulk flour (bags x pack size) and the same number of
empty bags, and adds the packed bags to Finished Goods. Finished stock is thus
driven by packing rather than typed in. `stock()` is the stock view for phones.
"""

import frappe
from frappe import _
from frappe.utils import flt, now_datetime

from astrasun.loading import _as_system
from astrasun.milling import PRODUCTION_ROLES, _company, _require, _warehouse
from astrasun.setup.masters import BULK_ITEMS, PACK_SIZES, bag_code, sku_code

PACKING_ROLES = PRODUCTION_ROLES + ("Mill Packing",)
STOCK_ROLES = PACKING_ROLES + ("Mill Warehouse", "Mill Dispatch", "Mill Sales", "Mill Accounts")


class PackingError(frappe.ValidationError):
	pass


def _qty(item_code, company):
	from erpnext.stock.utils import get_latest_stock_qty

	return flt(get_latest_stock_qty(item_code, _warehouse(item_code, company)))


def _skus():
	for bulk, sizes in PACK_SIZES.items():
		for kg in sizes:
			yield bulk, kg, sku_code(bulk, kg)


@frappe.whitelist()
def skus():
	"""What can be packed, with the bulk flour and empty bags on hand."""
	if not set(frappe.get_roles()).intersection(PACKING_ROLES):
		frappe.throw(_("Only packing staff can pack"), frappe.PermissionError)
	company = _company()
	return [
		{
			"item_code": code,
			"item_name": frappe.db.get_value("Item", code, "item_name"),
			"kg": kg,
			"bulk_kg": _qty(bulk, company),
			"empty_bags": _qty(bag_code(bulk, kg), company),
			"packed_bags": _qty(code, company),
		}
		for bulk, kg, code in _skus()
	]


@frappe.whitelist()
def stock():
	"""Wheat, bulk flour and packed bags in kg or bags, for the stock screen."""
	if not set(frappe.get_roles()).intersection(STOCK_ROLES):
		frappe.throw(_("You cannot see stock"), frappe.PermissionError)
	company = _company()
	rows = []
	for code in BULK_ITEMS:
		rows.append(
			{
				"item_code": code,
				"item_name": frappe.db.get_value("Item", code, "item_name"),
				"qty": _qty(code, company),
				"unit": "kg",
				"kind": "Raw" if code == "WHEAT" else "Bulk",
			}
		)
	for _bulk, _kg, code in _skus():
		rows.append(
			{
				"item_code": code,
				"item_name": frappe.db.get_value("Item", code, "item_name"),
				"qty": _qty(code, company),
				"unit": "bags",
				"kind": "Packed",
			}
		)
	return rows


@frappe.whitelist()
def pack(item_code, bags):
	"""Pack `bags` bags of one SKU from bulk flour and empty bags."""
	if not set(frappe.get_roles()).intersection(PACKING_ROLES):
		frappe.throw(_("Only packing staff can pack"), frappe.PermissionError)
	match = [(b, kg) for b, kg, code in _skus() if code == item_code]
	if not match:
		frappe.throw(_("Unknown bag size"), PackingError)
	bulk, kg = match[0]
	bags = flt(bags)
	if bags <= 0 or bags != int(bags):
		frappe.throw(_("Enter a whole number of bags"), PackingError)
	company = _company()
	bulk_kg = bags * kg
	if bulk_kg > _qty(bulk, company):
		frappe.throw(_("Not enough bulk flour for this many bags"), PackingError)
	empty = bag_code(bulk, kg)
	if bags > _qty(empty, company):
		frappe.throw(_("Not enough empty bags"), PackingError)

	bulk_wh = _warehouse(bulk, company)
	rate = flt(frappe.db.get_value("Bin", {"item_code": bulk, "warehouse": bulk_wh}, "valuation_rate"))
	user = frappe.session.user
	with _as_system():
		entry = frappe.get_doc(
			{
				"doctype": "Stock Entry",
				"stock_entry_type": "Repack",
				"company": company,
				"remarks": f"Packing {bags:.0f} x {item_code}",
				"items": [
					{"item_code": bulk, "qty": bulk_kg, "s_warehouse": bulk_wh},
					{"item_code": empty, "qty": bags, "s_warehouse": _warehouse(empty, company)},
					{
						"item_code": item_code,
						"qty": bags,
						"t_warehouse": _warehouse(item_code, company),
						"is_finished_item": 1,
					},
				],
			}
		)
		entry.insert()
		entry.submit()
		entry.db_set("owner", user, update_modified=False)
	return {
		"stock_entry": entry.name,
		"item_code": item_code,
		"bags": bags,
		"bulk_used_kg": bulk_kg,
		"packed_bags": _qty(item_code, company),
	}

"""Mill master data: item groups, items, warehouses and BOMs.

Pack sizes, bag types and milling ratios are placeholders until the Phase 0
workshop confirms them. Running setup_mill again is safe: it only adds what
is missing.
"""

import frappe

ITEM_GROUPS = ["Wheat", "Bulk Flour", "Finished Goods", "By-products", "Packaging"]

# warehouse name -> what it holds
WAREHOUSES = {
	"Raw Wheat": "Wheat accepted by QC",
	"QC Hold": "Wheat waiting for or failing QC",
	"Bulk Flour": "Milled flour before packing (WIP)",
	"By-products": "Chokar and other by-products",
	"Finished Goods": "Packed bags ready to sell",
	"Packaging Material": "Empty bags, labels, thread",
}

# code: (name, Hindi name, item group, HSN, default warehouse)
BULK_ITEMS = {
	"WHEAT": ("Wheat", "गेहूं", "Wheat", "100199", "Raw Wheat"),
	"ATTA-BULK": ("Atta (bulk)", "आटा (खुला)", "Bulk Flour", "110100", "Bulk Flour"),
	"MAIDA-BULK": ("Maida (bulk)", "मैदा (खुला)", "Bulk Flour", "110100", "Bulk Flour"),
	"SOOJI-BULK": ("Sooji (bulk)", "सूजी (खुली)", "Bulk Flour", "110311", "Bulk Flour"),
	"CHOKAR-BULK": ("Chokar (bulk)", "चोकर (खुला)", "By-products", "230230", "By-products"),
}

# Packed SKUs: bulk item -> pack sizes in kg (PRD Point 12: 5, 10, 26, 50 kg)
PACK_SIZES = {
	"ATTA-BULK": [5, 10, 26, 50],
	"MAIDA-BULK": [50],
	"SOOJI-BULK": [50],
	"CHOKAR-BULK": [50],
}

# Milling BOM per 1000 kg wheat (placeholder ratios; about 1% process loss)
MILLING_OUTPUT_KG = {"ATTA-BULK": 700, "MAIDA-BULK": 100, "SOOJI-BULK": 50, "CHOKAR-BULK": 140}
MILLING_INPUT_KG = 1000


def sku_code(bulk_code, kg):
	return f"{bulk_code.removesuffix('-BULK')}-{kg}KG"


def bag_code(bulk_code, kg):
	return f"BAG-{sku_code(bulk_code, kg)}"


def setup_mill(company):
	abbr = frappe.get_cached_value("Company", company, "abbr")
	setup_uoms()
	setup_item_groups()
	warehouses = setup_warehouses(company, abbr)
	setup_items(company, warehouses)
	setup_boms(company)
	frappe.db.commit()


def setup_uoms():
	for uom, whole in (("Kg", 0), ("Quintal", 0), ("Bag", 1), ("Nos", 1)):
		if not frappe.db.exists("UOM", uom):
			frappe.get_doc({"doctype": "UOM", "uom_name": uom, "must_be_whole_number": whole}).insert(
				ignore_permissions=True
			)
	if not frappe.db.exists("UOM Conversion Factor", {"from_uom": "Quintal", "to_uom": "Kg"}):
		frappe.get_doc(
			{
				"doctype": "UOM Conversion Factor",
				"category": _uom_category("Mass"),
				"from_uom": "Quintal",
				"to_uom": "Kg",
				"value": 100,
			}
		).insert(ignore_permissions=True)


def _uom_category(name):
	if not frappe.db.exists("UOM Category", name):
		frappe.get_doc({"doctype": "UOM Category", "category_name": name}).insert(ignore_permissions=True)
	return name


def setup_item_groups():
	root = frappe.db.get_value("Item Group", {"is_group": 1, "parent_item_group": ["in", ["", None]]})
	for group in ITEM_GROUPS:
		if not frappe.db.exists("Item Group", group):
			frappe.get_doc(
				{"doctype": "Item Group", "item_group_name": group, "parent_item_group": root}
			).insert(ignore_permissions=True)


def setup_warehouses(company, abbr):
	parent = frappe.db.get_value(
		"Warehouse", {"company": company, "is_group": 1, "parent_warehouse": ["in", ["", None]]}
	)
	names = {}
	for warehouse in WAREHOUSES:
		name = f"{warehouse} - {abbr}"
		if not frappe.db.exists("Warehouse", name):
			frappe.get_doc(
				{
					"doctype": "Warehouse",
					"warehouse_name": warehouse,
					"company": company,
					"parent_warehouse": parent,
				}
			).insert(ignore_permissions=True)
		names[warehouse] = name
	return names


def _ensure_item(company, code, item_name, group, stock_uom, warehouse, hsn=None, **extra):
	if frappe.db.exists("Item", code):
		return
	item = frappe.get_doc(
		{
			"doctype": "Item",
			"item_code": code,
			"item_name": item_name,
			"item_group": group,
			"stock_uom": stock_uom,
			"is_stock_item": 1,
			"include_item_in_manufacturing": 1,
			"item_defaults": [{"company": company, "default_warehouse": warehouse}],
			**extra,
		}
	)
	if hsn and item.meta.has_field("gst_hsn_code"):
		if not frappe.db.exists("GST HSN Code", hsn):
			frappe.get_doc({"doctype": "GST HSN Code", "hsn_code": hsn}).insert(ignore_permissions=True)
		item.gst_hsn_code = hsn
	item.insert(ignore_permissions=True)


def setup_items(company, warehouses):
	batch = {"has_batch_no": 1, "create_new_batch": 1}
	for code, (name, hindi, group, hsn, warehouse) in BULK_ITEMS.items():
		lot_prefix = "LOT-.YYYY.-.#####" if code == "WHEAT" else f"{code.removesuffix('-BULK')}-.YYYY.-.#####"
		_ensure_item(
			company,
			code,
			name,
			group,
			"Kg",
			warehouses[warehouse],
			hsn,
			description=f"{name} / {hindi}",
			is_purchase_item=int(code == "WHEAT"),
			is_sales_item=int(code != "WHEAT"),
			batch_number_series=lot_prefix,
			**batch,
		)

	for bulk_code, sizes in PACK_SIZES.items():
		name, hindi, _group, hsn, _wh = BULK_ITEMS[bulk_code]
		base_name, base_hindi = name.removesuffix(" (bulk)"), hindi.split(" (")[0]
		for kg in sizes:
			_ensure_item(
				company,
				sku_code(bulk_code, kg),
				f"{base_name} {kg} kg",
				"Finished Goods",
				"Bag",
				warehouses["Finished Goods"],
				hsn,
				description=f"{base_name} {kg} kg bag / {base_hindi} {kg} किलो",
				is_sales_item=1,
				is_purchase_item=0,
				weight_per_unit=kg,
				weight_uom="Kg",
				batch_number_series=f"PK-{sku_code(bulk_code, kg)}-.YYYY.-.#####",
				**batch,
			)
			_ensure_item(
				company,
				bag_code(bulk_code, kg),
				f"Empty bag: {base_name} {kg} kg",
				"Packaging",
				"Nos",
				warehouses["Packaging Material"],
				is_purchase_item=1,
				is_sales_item=0,
			)


def _ensure_bom(company, item, quantity, raw_items, scrap_items=()):
	if frappe.db.exists("BOM", {"item": item, "is_default": 1, "docstatus": 1}):
		return
	bom = frappe.get_doc(
		{
			"doctype": "BOM",
			"item": item,
			"company": company,
			"quantity": quantity,
			"is_active": 1,
			"is_default": 1,
			"rm_cost_as_per": "Valuation Rate",
			"items": [{"item_code": code, "qty": qty} for code, qty in raw_items],
			"scrap_items": [{"item_code": code, "stock_qty": qty} for code, qty in scrap_items],
		}
	)
	bom.insert(ignore_permissions=True)
	bom.submit()


def setup_boms(company):
	# Milling: wheat -> atta, with maida, sooji and chokar as by-products
	main_item = "ATTA-BULK"
	_ensure_bom(
		company,
		main_item,
		MILLING_OUTPUT_KG[main_item],
		[("WHEAT", MILLING_INPUT_KG)],
		[(code, kg) for code, kg in MILLING_OUTPUT_KG.items() if code != main_item],
	)

	# Packing: bulk flour + one empty bag -> one packed bag
	for bulk_code, sizes in PACK_SIZES.items():
		for kg in sizes:
			_ensure_bom(company, sku_code(bulk_code, kg), 1, [(bulk_code, kg), (bag_code(bulk_code, kg), 1)])

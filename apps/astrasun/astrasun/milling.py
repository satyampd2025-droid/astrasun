"""Milling: one shift's wheat in and flour out, with extraction % and downtime.

Recording a batch moves stock in one step: wheat leaves Raw Wheat, atta, maida,
sooji and chokar arrive in their warehouses. Extraction is flour (atta + maida
+ sooji) over wheat. Output above the wheat ground is impossible, and a low
extraction or a high process loss raises a flag for the owner.
"""

import frappe
from frappe import _
from frappe.utils import flt, now_datetime

from astrasun.loading import _as_system

PRODUCTION_ROLES = ("Mill Production", "Mill Manager", "Mill Owner")
SHIFTS = ("Morning", "Afternoon", "Night")

# Placeholders until the Phase 0 workshop gives the mill's real yield
MIN_EXTRACTION_PCT = 78.0
MAX_LOSS_PCT = 2.0

OUTPUTS = {
	"atta_kg": ("ATTA-BULK", "Bulk Flour"),
	"maida_kg": ("MAIDA-BULK", "Bulk Flour"),
	"sooji_kg": ("SOOJI-BULK", "Bulk Flour"),
	"chokar_kg": ("CHOKAR-BULK", "By-products"),
}


class MillingError(frappe.ValidationError):
	pass


def _require():
	if not set(frappe.get_roles()).intersection(PRODUCTION_ROLES):
		frappe.throw(_("Only production staff can record milling"), frappe.PermissionError)


def _company():
	return frappe.db.get_value("Item Default", {"parent": "WHEAT"}, "company")


def _warehouse(item_code, company):
	return frappe.db.get_value("Item Default", {"parent": item_code, "company": company}, "default_warehouse")


def _view(b):
	return {
		"name": b.name,
		"shift": b.shift,
		"run_at": str(b.run_at),
		"wheat_kg": flt(b.wheat_kg),
		"water_kg": flt(b.water_kg),
		"atta_kg": flt(b.atta_kg),
		"maida_kg": flt(b.maida_kg),
		"sooji_kg": flt(b.sooji_kg),
		"chokar_kg": flt(b.chokar_kg),
		"loss_kg": flt(b.loss_kg),
		"extraction_pct": flt(b.extraction_pct),
		"loss_pct": flt(b.loss_pct),
		"low_yield": bool(b.low_yield),
	}


@frappe.whitelist()
def wheat_available():
	_require()
	company = _company()
	from erpnext.stock.utils import get_latest_stock_qty

	return flt(get_latest_stock_qty("WHEAT", _warehouse("WHEAT", company)))


@frappe.whitelist()
def recent(limit=10):
	_require()
	names = frappe.get_all("Milling Batch", order_by="creation desc", limit=int(limit), pluck="name")
	return [_view(frappe.get_doc("Milling Batch", n)) for n in names]


@frappe.whitelist()
def record_batch(shift, wheat_kg, atta_kg, maida_kg, sooji_kg, chokar_kg, water_kg=0):
	"""Record one shift: wheat ground and what came out."""
	_require()
	if shift not in SHIFTS:
		frappe.throw(_("Choose the shift"), MillingError)
	out = {k: flt(v) for k, v in dict(atta_kg=atta_kg, maida_kg=maida_kg, sooji_kg=sooji_kg, chokar_kg=chokar_kg).items()}
	wheat = flt(wheat_kg)
	if wheat <= 0:
		frappe.throw(_("Enter the wheat ground"), MillingError)
	if any(v < 0 for v in out.values()) or flt(water_kg) < 0:
		frappe.throw(_("Quantities cannot be negative"), MillingError)
	total = sum(out.values())
	if total <= 0:
		frappe.throw(_("Enter what came out"), MillingError)
	if total > wheat * 1.05:
		# Tempering water adds a little weight; much more than wheat in is a wrong entry
		frappe.throw(_("Output is more than the wheat ground. Check the numbers."), MillingError)
	if wheat > wheat_available():
		frappe.throw(_("Not enough wheat in stock"), MillingError)

	company = _company()
	flour = out["atta_kg"] + out["maida_kg"] + out["sooji_kg"]
	loss = max(wheat - total, 0)
	extraction = flour / wheat * 100
	loss_pct = loss / wheat * 100
	user = frappe.session.user
	with _as_system():
		batch = frappe.get_doc(
			{
				"doctype": "Milling Batch",
				"shift": shift,
				"company": company,
				"run_at": now_datetime(),
				"run_by": user,
				"wheat_kg": wheat,
				"water_kg": flt(water_kg),
				**out,
				"output_kg": total,
				"flour_kg": flour,
				"loss_kg": loss,
				"extraction_pct": extraction,
				"loss_pct": loss_pct,
				"low_yield": int(extraction < MIN_EXTRACTION_PCT or loss_pct > MAX_LOSS_PCT),
			}
		)
		batch.insert()
		batch.stock_entry = _move_stock(batch, company, out)
		batch.save()
		batch.db_set("owner", user, update_modified=False)
	return _view(batch)


def _move_stock(batch, company, out):
	wheat_wh = _warehouse("WHEAT", company)
	items = [{"item_code": "WHEAT", "qty": flt(batch.wheat_kg), "s_warehouse": wheat_wh}]
	# Everything that came out costs the same per kg: the wheat's cost spread over the output.
	# (Placeholder costing until the owner decides how to split cost between products.)
	wheat_rate = flt(frappe.db.get_value("Bin", {"item_code": "WHEAT", "warehouse": wheat_wh}, "valuation_rate"))
	rate = wheat_rate * flt(batch.wheat_kg) / flt(batch.output_kg)
	first = True
	for field, (code, _group) in OUTPUTS.items():
		if out[field] > 0:
			items.append(
				{
					"item_code": code,
					"qty": out[field],
					"t_warehouse": _warehouse(code, company),
					"is_finished_item": int(first),
					"set_basic_rate_manually": 1,
					"basic_rate": rate,
				}
			)
			first = False
	entry = frappe.get_doc(
		{
			"doctype": "Stock Entry",
			"stock_entry_type": "Repack",
			"company": company,
			"remarks": f"Milling {batch.name} ({batch.shift})",
			"items": items,
		}
	)
	entry.insert()
	entry.submit()
	return entry.name


@frappe.whitelist()
def report_downtime(machine, minutes, reason):
	"""A machine stopped. Who, how long and why."""
	_require()
	machine = (machine or "").strip()
	if not machine or int(flt(minutes)) <= 0 or not (reason or "").strip():
		frappe.throw(_("Enter the machine, minutes and reason"), MillingError)
	user = frappe.session.user
	with _as_system():
		doc = frappe.get_doc(
			{
				"doctype": "Machine Downtime",
				"machine": machine,
				"minutes": int(flt(minutes)),
				"reason": reason.strip(),
				"reported_at": now_datetime(),
				"reported_by": user,
			}
		)
		doc.insert()
		doc.db_set("owner", user, update_modified=False)
	return {"name": doc.name, "machine": doc.machine, "minutes": doc.minutes, "reason": doc.reason}

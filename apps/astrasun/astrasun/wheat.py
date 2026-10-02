"""Wheat in: gate entry, weighbridge, lab check, unload to stock.

A truck becomes a Wheat Lot: At Gate -> Weighed In (loaded weight) ->
Released | On Hold | Rejected (lab) -> Received (empty weight, net goes to stock).
The weight on the supplier's slip is compared with the mill's own net weight;
a gap beyond WEIGHT_TOLERANCE_PCT raises an alert for the owner and manager.
"""

import frappe
from frappe import _
from frappe.utils import flt, now_datetime

from astrasun.loading import _as_system

GATE_ROLES = ("Mill Gate", "Mill Purchase", "Mill Manager", "Mill Owner")
QC_ROLES = ("Mill QC", "Mill Manager", "Mill Owner")
BOSS_ROLES = ("Mill Manager", "Mill Owner")

# Placeholders until the owner confirms them (see DECISIONS)
WEIGHT_TOLERANCE_PCT = 0.5
MAX_MOISTURE_PCT = 14.0
MAX_FOREIGN_MATTER_PCT = 2.0

AT_GATE, WEIGHED_IN, ON_HOLD, RELEASED, REJECTED, RECEIVED = (
	"At Gate",
	"Weighed In",
	"On Hold",
	"Released",
	"Rejected",
	"Received",
)
DECISIONS = {"Release": RELEASED, "Hold": ON_HOLD, "Reject": REJECTED}


class WheatError(frappe.ValidationError):
	pass


def _require(roles, message):
	if not set(frappe.get_roles()).intersection(roles):
		frappe.throw(_(message), frappe.PermissionError)


def _view(lot):
	return {
		"name": lot.name,
		"supplier": lot.supplier,
		"supplier_name": lot.supplier_name or lot.supplier,
		"vehicle_no": lot.vehicle_no,
		"status": lot.status,
		"rate_per_quintal": flt(lot.rate_per_quintal),
		"party_weight_kg": flt(lot.party_weight_kg),
		"gross_kg": flt(lot.gross_kg),
		"tare_kg": flt(lot.tare_kg),
		"net_kg": flt(lot.net_kg),
		"weight_gap_kg": flt(lot.weight_gap_kg),
		"weight_gap_pct": flt(lot.weight_gap_pct),
		"weight_alert": bool(lot.weight_alert),
		"moisture_pct": flt(lot.moisture_pct),
		"foreign_matter_pct": flt(lot.foreign_matter_pct),
		"broken_pct": flt(lot.broken_pct),
		"qc_remarks": lot.qc_remarks,
		"purchase_receipt": lot.purchase_receipt,
	}


def _lot(name, *statuses):
	lot = frappe.get_doc("Wheat Lot", name)
	if lot.status not in statuses:
		frappe.throw(_("This truck is {0}, not ready for this step").format(_(lot.status)), WheatError)
	return lot


def _company():
	return frappe.db.get_value("Item Default", {"parent": "WHEAT"}, "company") or frappe.defaults.get_user_default(
		"Company"
	)


@frappe.whitelist()
def suppliers():
	_require(GATE_ROLES + QC_ROLES, "Only gate and purchase staff can see suppliers")
	return frappe.get_all(
		"Supplier", filters={"disabled": 0}, fields=["name", "supplier_name"], order_by="supplier_name asc"
	)


@frappe.whitelist()
def trucks():
	"""Trucks still on their way through: everything except received and rejected."""
	_require(GATE_ROLES + QC_ROLES, "Only gate and lab staff can see trucks")
	names = frappe.get_all(
		"Wheat Lot",
		filters={"status": ["in", [AT_GATE, WEIGHED_IN, ON_HOLD, RELEASED]]},
		order_by="creation asc",
		pluck="name",
	)
	return [_view(frappe.get_doc("Wheat Lot", n)) for n in names]


@frappe.whitelist()
def gate_in(supplier, vehicle_no, party_weight_kg, rate_per_quintal):
	"""A truck arrives with the supplier's slip weight and the agreed rate."""
	_require(GATE_ROLES, "Only gate and purchase staff can enter trucks")
	vehicle_no = (vehicle_no or "").strip().upper()
	if not vehicle_no:
		frappe.throw(_("Enter the vehicle number"), WheatError)
	if flt(party_weight_kg) <= 0:
		frappe.throw(_("Enter the weight on the supplier's slip"), WheatError)
	if flt(rate_per_quintal) <= 0:
		frappe.throw(_("Enter the rate per quintal"), WheatError)
	lot = frappe.get_doc(
		{
			"doctype": "Wheat Lot",
			"supplier": supplier,
			"vehicle_no": vehicle_no,
			"company": _company(),
			"party_weight_kg": flt(party_weight_kg),
			"rate_per_quintal": flt(rate_per_quintal),
			"status": AT_GATE,
			"gate_in_at": now_datetime(),
		}
	)
	with _as_system():
		lot.insert()
		lot.db_set("owner", frappe.session.user, update_modified=False)
	return _view(lot)


@frappe.whitelist()
def weigh_in(name, gross_kg):
	"""Loaded truck on the weighbridge."""
	_require(GATE_ROLES, "Only gate staff can weigh trucks")
	lot = _lot(name, AT_GATE)
	if flt(gross_kg) <= 0:
		frappe.throw(_("Enter the weighbridge reading"), WheatError)
	lot.gross_kg = flt(gross_kg)
	lot.status = WEIGHED_IN
	with _as_system():
		lot.save()
	return _view(lot)


@frappe.whitelist()
def check(name, moisture_pct, foreign_matter_pct, broken_pct, decision, remarks=None):
	"""Lab result. Release, Hold or Reject; bad readings cannot be released by the lab alone."""
	_require(QC_ROLES, "Only the lab can check wheat")
	if decision not in DECISIONS:
		frappe.throw(_("Choose Release, Hold or Reject"), WheatError)
	lot = _lot(name, WEIGHED_IN, ON_HOLD)
	moisture, foreign, broken = flt(moisture_pct), flt(foreign_matter_pct), flt(broken_pct)
	for value in (moisture, foreign, broken):
		if not 0 <= value <= 100:
			frappe.throw(_("Percentages must be between 0 and 100"), WheatError)
	bad = moisture > MAX_MOISTURE_PCT or foreign > MAX_FOREIGN_MATTER_PCT
	if decision == "Release" and bad:
		if not set(frappe.get_roles()).intersection(BOSS_ROLES):
			frappe.throw(
				_("Moisture or foreign matter is over the limit. Only the manager or owner can release it."),
				frappe.PermissionError,
			)
		if not (remarks or "").strip():
			frappe.throw(_("Give a reason for releasing wheat that is over the limit"), WheatError)
	if decision in ("Reject", "Hold") and not (remarks or "").strip():
		frappe.throw(_("Give a reason"), WheatError)
	lot.moisture_pct, lot.foreign_matter_pct, lot.broken_pct = moisture, foreign, broken
	lot.qc_by = frappe.session.user
	lot.qc_remarks = remarks
	lot.status = DECISIONS[decision]
	with _as_system():
		lot.save()
	return _view(lot)


@frappe.whitelist()
def weigh_out(name, tare_kg):
	"""Empty truck after unloading: the net weight goes into stock."""
	_require(GATE_ROLES, "Only gate staff can weigh trucks")
	lot = _lot(name, RELEASED)
	tare = flt(tare_kg)
	if tare <= 0 or tare >= flt(lot.gross_kg):
		frappe.throw(_("The empty weight must be less than the loaded weight"), WheatError)
	net = flt(lot.gross_kg) - tare
	gap = net - flt(lot.party_weight_kg)
	gap_pct = abs(gap) / flt(lot.party_weight_kg) * 100
	lot.tare_kg, lot.net_kg = tare, net
	lot.weight_gap_kg, lot.weight_gap_pct = gap, gap_pct
	lot.weight_alert = int(gap_pct > WEIGHT_TOLERANCE_PCT)
	with _as_system():
		lot.purchase_receipt = _receive(lot)
		lot.status = RECEIVED
		lot.save()
	return _view(lot)


def _receive(lot):
	"""Wheat the mill has weighed (net) goes into the Raw Wheat warehouse at the agreed rate."""
	warehouse = frappe.db.get_value("Item Default", {"parent": "WHEAT", "company": lot.company}, "default_warehouse")
	pr = frappe.get_doc(
		{
			"doctype": "Purchase Receipt",
			"supplier": lot.supplier,
			"company": lot.company,
			"posting_date": frappe.utils.nowdate(),
			"remarks": f"Wheat lot {lot.name}, truck {lot.vehicle_no}",
			"items": [
				{
					"item_code": "WHEAT",
					"qty": flt(lot.net_kg),
					"uom": "Kg",
					"rate": flt(lot.rate_per_quintal) / 100,
					"warehouse": warehouse,
				}
			],
		}
	)
	pr.insert()
	pr.submit()
	return pr.name

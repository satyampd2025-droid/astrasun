"""Loading: the warehouse loads an approved order onto a vehicle.

An approved Sales Order shows in the loading queue. The loader starts a loading
task (a draft Delivery Note), picks the vehicle from the list the owner keeps
(the vehicle's driver comes with it), and marks it loaded with the bags actually
put on the truck. The Delivery Note stays a draft: dispatch
(submitting it) waits for the invoice, per DECISIONS D5.
"""

import json
import re
from contextlib import contextmanager

import frappe
from frappe import _
from frappe.utils import flt

from astrasun import audit, stages, vehicles

LOADER_ROLES = ("Mill Warehouse", "Mill Dispatch", "Mill Manager", "Mill Owner")
LOADING, LOADED = "Loading", "Loaded"
CHANGE_REQUESTED = "Requested"
APPROVER_ROLES = ("Mill Manager", "Mill Owner")


@contextmanager
def _as_system():
	user = frappe.session.user
	frappe.set_user("Administrator")
	try:
		yield
	finally:
		frappe.set_user(user)


class LoadingError(frappe.ValidationError):
	pass


def _check_role():
	if not set(frappe.get_roles()).intersection(LOADER_ROLES):
		frappe.throw(_("Only warehouse staff can load orders"), frappe.PermissionError)


def _assign_vehicle(dn, vehicle_no):
	"""Put the vehicle, and with it its driver, on the loading task."""
	vehicle = vehicles.find(vehicle_no)
	if not vehicle:
		frappe.throw(_("Pick a vehicle from the list"), LoadingError)
	dn.astrasun_vehicle_no = vehicle.vehicle_no
	dn.astrasun_driver_name = vehicle.driver_name
	dn.astrasun_driver_phone = vehicle.driver_phone
	dn.astrasun_driver_user = vehicle.driver_user


def _address(dn):
	"""Where to deliver, as one line of plain text."""
	text = dn.shipping_address or dn.address_display
	if not text:
		text = frappe.db.get_value("Customer", dn.customer, "primary_address") or ""
	text = re.sub(r"<br\s*/?>|</div>|\n", ", ", text)
	text = re.sub(r"<[^>]+>", "", text)
	return re.sub(r"\s*,(\s*,)+", ",", " ".join(text.split())).strip(" ,")


def _phone(dn):
	return dn.contact_mobile or frappe.db.get_value("Customer", dn.customer, "mobile_no")


def _task(dn):
	return {
		"name": dn.name,
		"sales_order": dn.items[0].against_sales_order if dn.items else None,
		"customer": dn.customer,
		"customer_name": dn.customer_name,
		"status": dn.astrasun_loading_status,
		"stage": stages.WAITING
		if dn.astrasun_change_status == CHANGE_REQUESTED
		else stages.truck_stage(dn.astrasun_loading_status),
		"vehicle_no": dn.astrasun_vehicle_no,
		"driver_name": dn.astrasun_driver_name,
		"driver_phone": dn.astrasun_driver_phone,
		"address": _address(dn),
		"customer_phone": _phone(dn),
		"loaded_by": dn.astrasun_loaded_by,
		"invoice": dn.astrasun_invoice,
		"change_requested": dn.astrasun_change_status == CHANGE_REQUESTED,
		"items": [
			{
				"item_code": r.item_code,
				"item_name": r.item_name,
				"qty": flt(r.qty),
				"rate": flt(r.rate),
				"amount": flt(r.amount),
			}
			for r in dn.items
		],
	}


def _waiting(so):
	return {
		"sales_order": so.name,
		"customer": so.customer,
		"customer_name": so.customer_name,
		"delivery_date": str(so.delivery_date),
		"status": "Waiting",
		"stage": stages.truck_stage("Waiting"),
		"items": [
			{"item_code": r.item_code, "item_name": r.item_name, "qty": flt(r.qty - r.delivered_qty)}
			for r in so.items
			if r.qty > r.delivered_qty
		],
	}


@frappe.whitelist()
def queue():
	"""Approved orders waiting to be loaded, and loading tasks in progress."""
	_check_role()
	started = frappe.get_all(
		"Delivery Note",
		filters={"docstatus": 0, "astrasun_loading_status": ["is", "set"]},
		order_by="creation asc",
		pluck="name",
	)
	tasks = [_task(frappe.get_doc("Delivery Note", n)) for n in started]
	taken = {t["sales_order"] for t in tasks}
	names = frappe.get_all(
		"Sales Order",
		filters={"docstatus": 1, "astrasun_approval_status": "Approved", "per_delivered": ["<", 100]},
		order_by="delivery_date asc, creation asc",
		pluck="name",
	)
	waiting = [_waiting(frappe.get_doc("Sales Order", n)) for n in names if n not in taken]
	return {"waiting": waiting, "loading": tasks}


@frappe.whitelist()
def start(sales_order, vehicle_no=None):
	"""Start loading an approved order: creates the draft Delivery Note.

	The vehicle can be picked now or when the load is marked done."""
	_check_role()
	from erpnext.selling.doctype.sales_order.sales_order import make_delivery_note

	so = frappe.get_doc("Sales Order", sales_order)
	if so.docstatus != 1 or so.astrasun_approval_status != "Approved":
		frappe.throw(_("Only approved orders can be loaded"), LoadingError)
	if frappe.db.exists("Delivery Note Item", {"against_sales_order": sales_order, "docstatus": 0}):
		frappe.throw(_("This order is already being loaded"), LoadingError)
	# Warehouse staff cannot read accounts, which ERPNext needs to fill in the note.
	# Our own role check above is what allows this.
	user = frappe.session.user
	with _as_system():
		dn = make_delivery_note(sales_order)
		dn.astrasun_loading_status = LOADING
		if (vehicle_no or "").strip():
			_assign_vehicle(dn, vehicle_no)
		dn.insert()
		dn.db_set("owner", user, update_modified=False)
	return _task(dn)


@frappe.whitelist()
def mark_loaded(name, vehicle_no, items=None):
	"""Record the vehicle and the bags actually loaded; `items` is [{item_code, qty}]."""
	_check_role()
	if not (vehicle_no or "").strip():
		frappe.throw(_("Pick the vehicle"), LoadingError)
	dn = frappe.get_doc("Delivery Note", name)
	if dn.docstatus != 0 or dn.astrasun_loading_status != LOADING:
		frappe.throw(_("This loading task is not open"), LoadingError)
	if dn.astrasun_change_status == CHANGE_REQUESTED:
		frappe.throw(_("A change is waiting for the owner"), LoadingError)
	if items:
		items = json.loads(items) if isinstance(items, str) else items
		loaded = {row["item_code"]: flt(row["qty"]) for row in items}
		ordered = {r.item_code: flt(r.qty) for r in dn.items}
		for code, qty in loaded.items():
			if code not in ordered or qty < 0 or qty > ordered[code]:
				frappe.throw(_("Loaded quantity for {0} is more than ordered").format(code), LoadingError)
		dn.items = [r for r in dn.items if loaded.get(r.item_code, 0) > 0]
		for r in dn.items:
			r.qty = loaded[r.item_code]
	if not dn.items:
		frappe.throw(_("Nothing was loaded"), LoadingError)
	_assign_vehicle(dn, vehicle_no)
	dn.astrasun_loading_status = LOADED
	dn.astrasun_loaded_by = frappe.session.user
	with _as_system():
		dn.save()
	return _task(dn)


def _ordered(dn):
	"""Bags the order asks for, by item: a load can be changed up to this, not beyond."""
	return {
		r.item_code: flt(r.qty)
		for r in frappe.get_all(
			"Sales Order Item",
			filters={"parent": dn.items[0].against_sales_order},
			fields=["item_code", "qty"],
		)
	}


@frappe.whitelist()
def request_change(name, items, reason):
	"""The load changed: the warehouse asks the owner to approve new bags, before the truck leaves.

	`items` is [{item_code, qty}] with the new bags for each item (0 takes an item off).
	Nothing changes until the owner approves; the truck cannot leave meanwhile.
	"""
	_check_role()
	reason = (reason or "").strip()
	if not reason:
		frappe.throw(_("Give a reason for the change"), LoadingError)
	dn = frappe.get_doc("Delivery Note", name)
	if dn.docstatus != 0 or dn.astrasun_loading_status not in (LOADING, LOADED):
		frappe.throw(_("Only a truck that has not left can be changed"), LoadingError)
	if dn.astrasun_change_status == CHANGE_REQUESTED:
		frappe.throw(_("A change is already waiting for the owner"), LoadingError)
	items = json.loads(items) if isinstance(items, str) else items
	wanted = {row["item_code"]: flt(row["qty"]) for row in items}
	ordered = _ordered(dn)
	for code, qty in wanted.items():
		if code not in ordered or qty < 0 or qty > ordered[code]:
			frappe.throw(
				_("{0}: more than the order asks for. Ask the rep to book another order.").format(code),
				LoadingError,
			)
	if not any(qty > 0 for qty in wanted.values()):
		frappe.throw(_("Nothing would be loaded. Ask the owner to cancel the order instead."), LoadingError)
	if all(wanted.get(r.item_code, 0) == flt(r.qty) for r in dn.items) and len(wanted) == len(dn.items):
		frappe.throw(_("These are the bags already loaded"), LoadingError)
	dn.astrasun_change_status = CHANGE_REQUESTED
	dn.astrasun_change_items = json.dumps(wanted)
	dn.astrasun_change_note = reason
	dn.astrasun_change_by = frappe.session.user
	with _as_system():
		dn.save()
	return _task(dn)


def _change_view(dn):
	task = _task(dn)
	task.update(
		{
			"new_items": [
				{"item_code": code, "qty": qty}
				for code, qty in json.loads(dn.astrasun_change_items or "{}").items()
			],
			"reason": dn.astrasun_change_note,
			"asked_by": dn.astrasun_change_by,
			"invoice": dn.astrasun_invoice,
		}
	)
	return task


@frappe.whitelist()
def change_requests():
	"""Load changes waiting for the owner or manager."""
	if not set(frappe.get_roles()).intersection(APPROVER_ROLES):
		frappe.throw(_("Only the owner or a manager can decide on load changes"), frappe.PermissionError)
	names = frappe.get_all(
		"Delivery Note",
		filters={"docstatus": 0, "astrasun_change_status": CHANGE_REQUESTED},
		order_by="modified asc",
		pluck="name",
	)
	return [_change_view(frappe.get_doc("Delivery Note", n)) for n in names]


@frappe.whitelist()
def decide_change(name, approve, note=None):
	"""Approve or turn down a load change.

	Approving puts the new bags on the load and cancels the bill already printed; the warehouse
	then taps Print bill again for the new one. Turning it down leaves the load and bill as they are.
	"""
	if not set(frappe.get_roles()).intersection(APPROVER_ROLES):
		frappe.throw(_("Only the owner or a manager can decide on load changes"), frappe.PermissionError)
	dn = frappe.get_doc("Delivery Note", name)
	if dn.docstatus != 0 or dn.astrasun_change_status != CHANGE_REQUESTED:
		frappe.throw(_("There is no change waiting on this truck"), LoadingError)
	wanted = json.loads(dn.astrasun_change_items or "{}")
	decision = "approved" if int(approve) else "turned down"
	old_invoice = dn.astrasun_invoice
	reason = dn.astrasun_change_note
	with _as_system():
		if int(approve):
			if old_invoice:
				si = frappe.get_doc("Sales Invoice", old_invoice)
				si.flags.change_reason = f"Load changed: {reason}"
				si.cancel()
				dn.astrasun_invoice = None
			dn.items = [r for r in dn.items if flt(wanted.get(r.item_code, 0)) > 0]
			for r in dn.items:
				r.qty = flt(wanted[r.item_code])
		dn.astrasun_change_status = None
		dn.astrasun_change_items = None
		dn.astrasun_change_by = None
		dn.astrasun_change_note = None
		dn.save()
	audit.log(dn, "Approval", f"Load change {decision}: {reason}" + (f" ({note})" if note else ""))
	return _task(dn)

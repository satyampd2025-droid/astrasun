"""Vehicles: the trucks the mill loads, each with the driver who goes with it.

The owner adds every vehicle beforehand. At loading the warehouse picks one from
the list, and the driver comes with it: that driver's phone then shows the order.
"""

import re

import frappe
from frappe import _

MANAGER_ROLES = ("Mill Manager", "Mill Owner")
LIST_ROLES = ("Mill Warehouse", "Mill Dispatch", *MANAGER_ROLES)


class VehicleError(frappe.ValidationError):
	pass


def vehicle_key(vehicle_no):
	"""'mp 09 ab-1234' and 'MP09AB1234' are the same vehicle."""
	return re.sub(r"[\s-]+", "", (vehicle_no or "")).upper()


def _check(roles, message):
	if not set(frappe.get_roles()).intersection(roles):
		frappe.throw(_(message), frappe.PermissionError)


def _row(vehicle):
	return {
		"vehicle_no": vehicle.vehicle_no,
		"driver_name": vehicle.driver_name,
		"driver_phone": vehicle.driver_phone,
		"driver_user": vehicle.driver_user,
		"enabled": bool(vehicle.enabled),
	}


@frappe.whitelist()
def vehicles(all=0):
	"""The vehicles to pick from at loading. Managers can ask for the unavailable ones too."""
	_check(LIST_ROLES, "Only warehouse staff can see vehicles")
	filters = {} if int(all or 0) and set(frappe.get_roles()).intersection(MANAGER_ROLES) else {"enabled": 1}
	rows = frappe.get_all(
		"Mill Vehicle",
		filters=filters,
		fields=["vehicle_no", "driver_name", "driver_phone", "driver_user", "enabled"],
		order_by="vehicle_no asc",
	)
	return [_row(r) for r in rows]


@frappe.whitelist()
def save(vehicle_no, driver_name, driver_phone=None, driver_user=None, enabled=1):
	"""Add a vehicle, or change its driver or availability."""
	_check(MANAGER_ROLES, "Only the owner or manager can add vehicles")
	key = vehicle_key(vehicle_no)
	driver_name = (driver_name or "").strip()
	driver_user = (driver_user or "").strip() or None
	if not key:
		frappe.throw(_("Enter the vehicle number"), VehicleError)
	if not driver_name:
		frappe.throw(_("Enter the driver's name"), VehicleError)
	if driver_user:
		if not frappe.db.exists("User", driver_user):
			frappe.throw(_("There is no app login {0}").format(driver_user), VehicleError)
		if "Mill Driver" not in frappe.get_roles(driver_user):
			frappe.throw(_("{0} does not have the Driver job").format(driver_user), VehicleError)
	values = {
		"driver_name": driver_name,
		"driver_phone": (driver_phone or "").strip() or None,
		"driver_user": driver_user,
		"enabled": 1 if int(enabled) else 0,
	}
	if frappe.db.exists("Mill Vehicle", key):
		doc = frappe.get_doc("Mill Vehicle", key)
		doc.update(values)
		doc.save()
	else:
		doc = frappe.get_doc({"doctype": "Mill Vehicle", "vehicle_no": key, **values}).insert()
	return _row(doc)


def find(vehicle_no):
	"""The available vehicle with this number, or None."""
	vehicle = frappe.db.get_value(
		"Mill Vehicle",
		vehicle_key(vehicle_no),
		["vehicle_no", "driver_name", "driver_phone", "driver_user", "enabled"],
		as_dict=True,
	)
	return vehicle if vehicle and vehicle.enabled else None

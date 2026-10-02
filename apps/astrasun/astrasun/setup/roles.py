import frappe

# One profile per job in the mill. Each bundles standard ERPNext roles plus a
# mill role of the same name, which our own screens and alerts check.
ROLE_PROFILES = {
	"Mill Owner": [
		"System Manager",
		"Accounts Manager",
		"Sales Manager",
		"Purchase Manager",
		"Stock Manager",
		"Manufacturing Manager",
		"Quality Manager",
		"Item Manager",
	],
	"Mill Manager": [
		"Sales Manager",
		"Purchase Manager",
		"Stock Manager",
		"Manufacturing Manager",
		"Quality Manager",
	],
	"Mill Sales": ["Sales User"],
	"Mill Purchase": ["Purchase User", "Stock User"],
	"Mill Gate": ["Stock User"],
	"Mill QC": ["Quality Manager"],
	"Mill Production": ["Manufacturing User"],
	"Mill Packing": ["Manufacturing User", "Stock User"],
	"Mill Warehouse": ["Stock User"],
	"Mill Dispatch": ["Stock User"],
	"Mill Driver": [],
	"Mill Accounts": ["Accounts User", "Accounts Manager"],
	"Mill Auditor": ["Auditor"],
}

# Roles that can read the Critical Change Log.
AUDIT_READERS = ["Mill Owner", "Mill Auditor", "Auditor", "System Manager"]


def setup_roles():
	for mill_role, erp_roles in ROLE_PROFILES.items():
		if not frappe.db.exists("Role", mill_role):
			frappe.get_doc({"doctype": "Role", "role_name": mill_role, "desk_access": 1}).insert(
				ignore_permissions=True
			)

	for mill_role, erp_roles in ROLE_PROFILES.items():
		roles = [mill_role, *[r for r in erp_roles if frappe.db.exists("Role", r)]]
		if frappe.db.exists("Role Profile", mill_role):
			profile = frappe.get_doc("Role Profile", mill_role)
		else:
			profile = frappe.new_doc("Role Profile")
			profile.role_profile = mill_role
		existing = {r.role for r in profile.roles}
		for role in roles:
			if role not in existing:
				profile.append("roles", {"role": role})
		profile.save(ignore_permissions=True)

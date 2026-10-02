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


def bundled_roles(held):
	"""Standard roles that the mill jobs among `held` bring with them and that `held` does not have yet."""
	wanted = {role for job, bundle in ROLE_PROFILES.items() if job in held for role in bundle}
	return sorted(role for role in wanted - set(held) if frappe.db.exists("Role", role))


def add_bundled_roles(doc, method=None):
	"""User validate hook: whoever holds a mill job also holds the standard roles that job needs.

	The Role Profile already does this, but an account made by ticking roles one by one would have the
	job and none of its permissions: ERPNext then refuses the work ("does not have doctype access via
	role permission for document Sales Order").
	"""
	for role in bundled_roles({row.role for row in doc.roles}):
		doc.append("roles", {"role": role})


def sync_users():
	"""Bring accounts made before add_bundled_roles existed up to date. Runs after every migrate."""
	filters = {"parenttype": "User", "role": ["in", list(ROLE_PROFILES)]}
	accounts = set(frappe.get_all("Has Role", filters=filters, pluck="parent")) - {"Administrator", "Guest"}
	for name in sorted(accounts):
		doc = frappe.get_doc("User", name)
		if bundled_roles({row.role for row in doc.roles}):
			doc.save(ignore_permissions=True)

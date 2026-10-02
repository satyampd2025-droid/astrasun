"""Endpoints for the phone app."""

import frappe
from frappe import _

from astrasun.setup.roles import ROLE_PROFILES

LANGUAGES = ("en", "hi")


@frappe.whitelist()
def me():
	"""Who is logged in, which mill jobs they do and which language they use."""
	user = frappe.session.user
	if user == "Guest":
		frappe.throw(_("Please log in"), frappe.AuthenticationError)
	roles = set(frappe.get_roles(user))
	mill_roles = [role for role in ROLE_PROFILES if role in roles]
	# Administrator holds every role; show the owner's home rather than all of them.
	if user == "Administrator" or ("System Manager" in roles and not mill_roles):
		mill_roles = ["Mill Owner"]
	return {
		"user": user,
		"full_name": frappe.utils.get_fullname(user),
		"language": frappe.db.get_value("User", user, "language") or "en",
		"mill_roles": mill_roles,
	}


@frappe.whitelist()
def set_language(language):
	"""Save the user's language so the web desk and the phone app match."""
	if language not in LANGUAGES:
		frappe.throw(_("Language must be one of {0}").format(", ".join(LANGUAGES)))
	frappe.db.set_value("User", frappe.session.user, "language", language)
	frappe.clear_cache(user=frappe.session.user)
	return language

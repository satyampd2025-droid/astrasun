import frappe
from frappe import _
from frappe.model.document import Document


class CriticalChangeLog(Document):
	"""Append-only audit trail. Written by astrasun.audit; nobody edits or deletes it."""

	def on_update(self):
		if not self.flags.in_insert:
			frappe.throw(_("Critical Change Log cannot be edited"))

	def on_trash(self):
		frappe.throw(_("Critical Change Log cannot be deleted"))

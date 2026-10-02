import frappe
from frappe.custom.doctype.custom_field.custom_field import create_custom_fields

FIELDS = {
	"Delivery Note": [
		{
			"fieldname": "astrasun_loading_section",
			"label": "Mill loading",
			"fieldtype": "Section Break",
			"insert_after": "scan_barcode",
			"collapsible": 1,
		},
		{
			"fieldname": "astrasun_loading_status",
			"label": "Loading Status",
			"fieldtype": "Select",
			"options": "Loading\nLoaded",
			"default": "Loading",
			"in_list_view": 1,
			"in_standard_filter": 1,
			"no_copy": 1,
			"read_only": 1,
			"allow_on_submit": 1,
			"insert_after": "astrasun_loading_section",
		},
		{
			"fieldname": "astrasun_vehicle_no",
			"label": "Vehicle Number",
			"fieldtype": "Data",
			"no_copy": 1,
			"allow_on_submit": 1,
			"insert_after": "astrasun_loading_status",
		},
		{
			"fieldname": "astrasun_loaded_by",
			"label": "Loaded By",
			"fieldtype": "Link",
			"options": "User",
			"read_only": 1,
			"no_copy": 1,
			"allow_on_submit": 1,
			"insert_after": "astrasun_vehicle_no",
		},
	]
}


def setup_loading_fields():
	create_custom_fields(FIELDS, update=True)

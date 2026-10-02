app_name = "astrasun"
app_title = "Astrasun"
app_publisher = "Astrasun Global LLP"
app_description = "Atulyaa mill operations app on ERPNext"
app_email = "satyampd2025@gmail.com"
app_license = "gpl-3.0"
required_apps = ["frappe/erpnext"]

after_install = "astrasun.setup.install.after_install"
after_migrate = "astrasun.setup.install.after_migrate"
setup_wizard_complete = "astrasun.setup.install.setup_wizard_complete"

# Audit with mandatory reason on critical changes (see astrasun/audit.py)
doc_events = {
	"*": {
		"validate": "astrasun.audit.validate",
		"on_update": "astrasun.audit.on_update",
		"before_submit": "astrasun.audit.before_submit",
		"on_submit": "astrasun.audit.on_submit",
		"before_cancel": "astrasun.audit.before_cancel",
		"on_cancel": "astrasun.audit.on_cancel",
	},
	# A mill job always brings the standard roles it needs (see astrasun/setup/roles.py)
	"User": {"validate": "astrasun.setup.roles.add_bundled_roles"},
}

"""Tries the order the phone sends ("Send for approval") on this server and prints the server's own answer.

Runs inside the backend container, from the sites folder, through docker/try-order.sh. It tries as the
administrator and as each enabled user who has a selling job (Mill Sales, Mill Manager or Mill Owner; the
wizard's own account holds them all). Nothing is saved: every try is rolled back, and commits are switched
off for the whole run.
"""

import json
import os
import re
import traceback

import frappe

frappe.init(site=os.environ["SITE"], sites_path=".")
frappe.connect()
frappe.db.commit = lambda *args, **kwargs: None  # whatever the code under test does, nothing is kept

from astrasun import orders  # noqa: E402  (needs the site connection first)
from astrasun.setup.roles import ROLE_PROFILES  # noqa: E402

SELLING_JOBS = ["Mill Sales", "Mill Manager", "Mill Owner"]


def say(line=""):
	print(line, flush=True)


def plain(text):
	return re.sub(r"\s+", " ", re.sub(r"<[^>]*>", "", str(text))).strip()


def pick_customer():
	customers = orders.catalog()["customers"]
	wanted = os.environ.get("CUSTOMER", "").strip().lower()
	for customer in customers:
		if wanted in (customer["name"].lower(), customer["customer_name"].lower()):
			return customer["name"]
	if wanted:
		say(f"No customer called '{wanted}'; using the first one instead.")
	return customers[0]["name"] if customers else None


def pick_item():
	items = orders.catalog()["items"]
	priced = [item for item in items if item["rate"] > 0]
	return (priced or items or [None])[0]


def show_facts(customer, item):
	company = orders._company(item["item_code"])
	country, category = frappe.db.get_value("Company", company, ["country", "gst_category"])
	addresses = frappe.db.sql(
		"""select a.gstin, a.disabled from `tabAddress` a join `tabDynamic Link` d on d.parent = a.name
		where d.link_doctype = 'Company' and d.link_name = %s""",
		(company,),
	)
	with_gstin = sum(1 for gstin, disabled in addresses if gstin and not disabled)
	say(f"Company:   {company} ({country}, GST category {category}); addresses with a GSTIN: {with_gstin} of {len(addresses)}")
	group, hsn, warehouse = (
		frappe.db.get_value("Item", item["item_code"], ["item_group", "gst_hsn_code"])
		+ (orders._warehouse(item["item_code"], company),)
	)
	say(f"Item:      {item['item_code']} ({item['item_name']}), group {group}, HSN {hsn}, warehouse {warehouse}, price {item['rate']}")
	cgroup, ccategory = frappe.db.get_value("Customer", customer, ["customer_group", "gst_category"])
	say(f"Customer:  {customer} (group {cgroup}, GST category {ccategory})")
	filters = {"parenttype": "Role Profile", "parent": "Mill Sales"}
	profile = frappe.get_all("Has Role", filters=filters, pluck="role")
	say(f"Role Profile Mill Sales brings: {', '.join(profile) or 'nothing (profile missing)'}")


def describe(user):
	"""The user's name, mill jobs and whether ERPNext lets them create a Sales Order."""
	if user == "Administrator":
		return user
	roles = set(frappe.get_roles(user))
	jobs = ", ".join(job for job in ROLE_PROFILES if job in roles) or "none"
	may = "yes" if frappe.has_permission("Sales Order", "create", user=user) else "no"
	return f"{user} (mill jobs: {jobs}; may create Sales Orders: {may})"


def printed():
	"""What the server printed to the user while refusing: the line the phone shows when the error has no text."""
	said = []
	for entry in frappe.local.message_log or []:
		if isinstance(entry, str):
			try:
				entry = json.loads(entry)
			except ValueError:
				entry = {"message": entry}
		text = plain(entry.get("message", "")) if isinstance(entry, dict) else ""
		if text:
			said.append(text)
	return " | ".join(said)


def attempt(user, customer, item):
	frappe.set_user(user)
	frappe.local.message_log = []
	try:
		order = orders.create_order(customer, [{"item_code": item["item_code"], "qty": 1, "rate": item["rate"]}])
		return f"OK. It would be saved and sent for approval as {order['name']} (rolled back, nothing kept)."
	except Exception as error:
		detail = plain(error) or printed() or type(error).__name__
		if not isinstance(error, frappe.ValidationError | frappe.PermissionError):
			detail += " | " + " / ".join(traceback.format_exc().strip().splitlines()[-4:])
		return f"REFUSED ({type(error).__name__}): {detail}"
	finally:
		frappe.db.rollback()
		frappe.set_user("Administrator")


try:
	frappe.set_user("Administrator")
	customer, item = pick_customer(), pick_item()
	if not customer or not item:
		say("Nothing to try: the phone needs at least one customer and one item in Item Group 'Finished Goods'.")
	else:
		show_facts(customer, item)
		sellers = frappe.get_all(
			"Has Role", filters={"role": ["in", SELLING_JOBS], "parenttype": "User"}, pluck="parent"
		)
		users = ["Administrator"] + [
			user for user in dict.fromkeys(sellers)
			if user != "Administrator" and frappe.db.get_value("User", user, "enabled")
		]
		say()
		for user in users[:8]:
			say(f"As {describe(user)}:")
			say(f"  {attempt(user, customer, item)}")
finally:
	frappe.db.rollback()
	frappe.destroy()

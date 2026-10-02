"""Rehearsal on a throwaway copy of the server: send the order the phone sends, as different users.

Run inside the backend container, from the sites folder:  ../env/bin/python - < order_rehearsal.py
Prints one line per try: OK or FAIL, the HTTP status and the server's own message. Not for the live server.
"""

import http.cookiejar
import json
import os
import traceback
import urllib.error
import urllib.request

import frappe

SITE = "mill.localhost"
BASE = "http://127.0.0.1:8000"
COMPANY = "Astrasun Global LLP"
ITEM = "ATTA-50KG"
CUSTOMER = "Gautam kumar singh"
PASSWORD = "Rehearsal-Pass-12345"
ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "ci-admin-pass-1")
WIZARD_USER = "wizard.owner@example.com"
# A published sample GSTIN (its check digit is valid); state code 27 is Maharashtra
GSTIN = "27AAPFU0939F1ZV"

frappe.init(site=SITE, sites_path=".")
frappe.connect()
frappe.set_user("Administrator")

failures = []


def show(title, value=""):
	print(f"{title}{': ' if value != '' else ''}{value}", flush=True)


def setup():
	from frappe.utils.password import update_password

	if not frappe.db.exists("Item Price", {"item_code": ITEM, "price_list": "Standard Selling"}):
		frappe.get_doc(
			{"doctype": "Item Price", "item_code": ITEM, "price_list": "Standard Selling", "price_list_rate": 1025}
		).insert()

	for email, profile in (("rep@example.com", "Mill Sales"), ("owner@example.com", "Mill Owner")):
		if not frappe.db.exists("User", email):
			frappe.get_doc(
				{
					"doctype": "User",
					"email": email,
					"first_name": email.split("@")[0],
					"send_welcome_email": 0,
					"role_profile_name": profile,
				}
			).insert()
			update_password(email, PASSWORD)

	if not frappe.db.exists("Customer", CUSTOMER):
		frappe.get_doc({"doctype": "Customer", "customer_name": CUSTOMER}).insert()
	frappe.db.commit()


def facts():
	show("Company", json.dumps(frappe.db.get_value("Company", COMPANY, ["country", "default_currency", "gst_category", "abbr"], as_dict=True)))
	show("Item Default", json.dumps(frappe.get_all("Item Default", filters={"parent": ITEM}, fields=["company", "default_warehouse"])))
	show("Item", json.dumps(frappe.db.get_value("Item", ITEM, ["item_group", "gst_hsn_code", "is_stock_item", "stock_uom"], as_dict=True)))
	show("GST Settings", json.dumps({k: frappe.db.get_single_value("GST Settings", k) for k in ("validate_hsn_code", "min_hsn_digits")}))
	show("Customer", json.dumps(frappe.db.get_value("Customer", CUSTOMER, ["customer_group", "territory", "customer_type", "gst_category"], as_dict=True)))
	show("Price lists", json.dumps(frappe.get_all("Price List", fields=["name", "currency", "selling", "enabled"])))
	for email in ("Administrator", WIZARD_USER, "rep@example.com", "owner@example.com"):
		roles = sorted(frappe.get_roles(email)) if frappe.db.exists("User", email) else ["(no such user)"]
		show(f"Roles of {email}", ", ".join(roles))


def server_message(text):
	try:
		data = json.loads(text)
	except ValueError:
		return text[:300].replace("\n", " ")
	message = data.get("message")
	if isinstance(message, dict) and "name" in message:
		return f"order {message['name']} status={message.get('status')} total={message.get('total')} stock_short={message.get('stock_short')}"
	parts = []
	for raw in json.loads(data.get("_server_messages") or "[]"):
		try:
			parts.append(json.loads(raw).get("message", raw))
		except ValueError:
			parts.append(raw)
	return f"exc_type={data.get('exc_type')} messages={parts} exception={str(data.get('exception'))[:300]}"


class Session:
	def __init__(self, email, password):
		self.opener = urllib.request.build_opener(
			urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())
		)
		code, text = self.call("login", {"usr": email, "pwd": password})
		if code != 200:
			raise RuntimeError(f"login as {email} failed: HTTP {code} {text[:200]}")

	def call(self, method, body):
		request = urllib.request.Request(
			f"{BASE}/api/method/{method}",
			data=json.dumps(body).encode(),
			headers={
				"Accept": "application/json",
				"Content-Type": "application/json",
				"Host": SITE,
				"X-Frappe-Site-Name": SITE,
			},
			method="POST",
		)
		try:
			with self.opener.open(request, timeout=120) as res:
				return res.status, res.read().decode()
		except urllib.error.HTTPError as error:
			return error.code, error.read().decode()


def place(label, email, password, send=1, customer=CUSTOMER):
	"""What the phone does: log in, then astrasun.orders.create_order with the same body."""
	try:
		session = Session(email, password)
		code, text = session.call(
			"astrasun.orders.create_order",
			{"customer": customer, "items": [{"item_code": ITEM, "qty": 3, "rate": 1025}], "remarks": "", "send": send},
		)
	except Exception:
		failures.append(label)
		show(f"[ERROR] {label}", traceback.format_exc()[-500:])
		return
	if code != 200:
		failures.append(label)
	show(f"[{'OK  ' if code == 200 else 'FAIL'}] {label}", f"HTTP {code} {server_message(text)}")


def place_as_everyone(prefix):
	for who, email, password in (
		("Administrator", "Administrator", ADMIN_PASSWORD),
		("wizard user", WIZARD_USER, PASSWORD),
		("Mill Sales rep", "rep@example.com", PASSWORD),
		("Mill Owner", "owner@example.com", PASSWORD),
	):
		place(f"{prefix}{who}, saved only", email, password, send=0)
		place(f"{prefix}{who}, sent for approval", email, password, send=1)


def set_company_registered():
	frappe.db.set_value("Company", COMPANY, "gst_category", "Registered Regular")
	frappe.db.commit()
	frappe.clear_cache()


def add_company_gstin():
	if frappe.db.exists("Address", {"gstin": GSTIN}):
		return
	frappe.get_doc(
		{
			"doctype": "Address",
			"address_title": COMPANY,
			"address_type": "Billing",
			"address_line1": "1 Mill Road",
			"city": "Mumbai",
			"state": "Maharashtra",
			"country": "India",
			"pincode": "400001",
			"gst_category": "Registered Regular",
			"gstin": GSTIN,
			"is_your_company_address": 1,
			"links": [{"link_doctype": "Company", "link_name": COMPANY}],
		}
	).insert()
	frappe.db.commit()
	frappe.clear_cache()


show("=== Setup")
setup()
facts()

show("=== What me() says for each user")
for who, email, password in (("Administrator", "Administrator", ADMIN_PASSWORD), ("wizard user", WIZARD_USER, PASSWORD), ("rep", "rep@example.com", PASSWORD)):
	try:
		code, text = Session(email, password).call("astrasun.api.me", {})
		show(f"{who}", f"HTTP {code} {text[:300]}")
	except Exception:
		show(f"[ERROR] me() for {who}", traceback.format_exc()[-300:])

show("=== Company as the wizard made it (no GSTIN anywhere)")
place_as_everyone("")

show("=== Company marked Registered Regular, still no GSTIN")
try:
	set_company_registered()
	place("Mill Sales rep, registered company without GSTIN", "rep@example.com", PASSWORD)
except Exception:
	show("[ERROR] scenario", traceback.format_exc()[-500:])

show("=== Company with an address that has a GSTIN")
try:
	add_company_gstin()
	place("Mill Sales rep, registered company with GSTIN address", "rep@example.com", PASSWORD)
except Exception:
	show("[ERROR] scenario", traceback.format_exc()[-800:])

frappe.db.commit()
show("=== Error Log (server exceptions, newest first)")
for row in frappe.get_all("Error Log", fields=["creation", "method", "error"], order_by="creation desc", limit=5):
	show(f"{row.creation} {row.method}", (row.error or "")[-1500:])

show("=== Summary", f"{len(failures)} failing: {failures}")

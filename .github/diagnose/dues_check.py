"""Customer dues over HTTP, the way the phone asks for them: who may look and who may receive money.

Run inside the backend container, from the sites folder:  ../env/bin/python - < dues_check.py
Needs rep@example.com (Mill Sales) and owner@example.com (Mill Owner) from order_rehearsal.py.
Prints one line per try and exits 1 if any answer is not the expected one. Not for the live server.
"""

import http.cookiejar
import json
import sys
import urllib.error
import urllib.request

import frappe

SITE = "mill.localhost"
BASE = "http://127.0.0.1:8000"
PASSWORD = "Rehearsal-Pass-12345"

frappe.init(site=SITE, sites_path=".")
frappe.connect()
frappe.set_user("Administrator")

from frappe.utils.password import update_password  # noqa: E402

if not frappe.db.exists("User", "loader@example.com"):
	frappe.get_doc(
		{
			"doctype": "User",
			"email": "loader@example.com",
			"first_name": "loader",
			"send_welcome_email": 0,
			"role_profile_name": "Mill Warehouse",
		}
	).insert()
	update_password("loader@example.com", PASSWORD)
	frappe.db.commit()

failures = []


def session(email):
	opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
	code, text = call(opener, "login", {"usr": email, "pwd": PASSWORD})
	assert code == 200, f"login as {email}: HTTP {code} {text[:200]}"
	return opener


def call(opener, method, body):
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
		with opener.open(request, timeout=120) as res:
			return res.status, res.read().decode()
	except urllib.error.HTTPError as error:
		return error.code, error.read().decode()


def reason(text):
	"""The first server message, as the phone reads it."""
	try:
		raw = json.loads(json.loads(text).get("_server_messages") or "[]")
		return json.loads(raw[0]).get("message", "") if raw else ""
	except (ValueError, TypeError, AttributeError):
		return text[:200]


def check(label, email, method, body, want_code, want_text=""):
	code, text = call(session(email), method, body)
	ok = code == want_code and want_text in (reason(text) if code != 200 else "")
	detail = f"{len(json.loads(text)['message'])} customers owe money" if code == 200 else reason(text)
	print(f"[{'OK  ' if ok else 'FAIL'}] {label}: HTTP {code} {detail}", flush=True)
	if not ok:
		failures.append(label)


check("sales rep looks at dues", "rep@example.com", "astrasun.payments.dues", {}, 200)
check(
	"sales rep tries to receive money",
	"rep@example.com",
	"astrasun.payments.collect",
	{"customer": "Gautam kumar singh", "amount": 1, "mode": "Cash"},
	403,
	"Only drivers and accounts staff can collect payment",
)
check("owner looks at dues", "owner@example.com", "astrasun.payments.dues", {}, 200)
check(
	"warehouse user tries to look at dues",
	"loader@example.com",
	"astrasun.payments.dues",
	{},
	403,
	"Only sales, drivers and accounts staff can see customer dues",
)

frappe.destroy()
sys.exit(1 if failures else 0)

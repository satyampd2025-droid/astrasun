// Opens the throwaway back-office in a real browser and does what the user did: click "Add Item" on
// the Item list (and the same through frappe.new_doc, which is what "New Item" in the search bar
// does), plus the full New Item page and a real save through the pop-up. Every stage prints as it
// finishes with a VERDICT line; screenshots and results go to out/.
//   SESSIONS=phone,desktop  which browsers to run     PHASE=name  label for the output files
const { chromium } = require('playwright-core');
const fs = require('fs');

const BASE = 'http://localhost:8080';
const PASSWORD = process.env.ADMIN_PASSWORD;
const PHASE = process.env.PHASE || 'run';
const SESSIONS = (process.env.SESSIONS || 'phone,desktop').split(',');
const OUT = 'out';
const results = {};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const withTimeout = (p, ms, what) =>
	Promise.race([p, new Promise((_, rej) => setTimeout(() => rej(new Error(`${what} timed out after ${ms} ms`)), ms))]);

const DEVICES = {
	phone: {
		viewport: { width: 412, height: 915 },
		deviceScaleFactor: 2,
		isMobile: true,
		hasTouch: true,
		userAgent:
			'Mozilla/5.0 (Linux; Android 14; SM-S911B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36',
	},
	desktop: { viewport: { width: 1280, height: 900 } },
};

async function modals(page) {
	return page.evaluate(() =>
		[...document.querySelectorAll('.modal.show')].map((el) => el.innerText.replace(/\s+/g, ' ').trim().slice(0, 300))
	);
}

async function session(browser, label) {
	const tag = `${PHASE}/${label}`;
	const say = (...a) => console.log(`[${tag} ${new Date().toISOString().slice(11, 19)}]`, ...a);
	const r = (results[tag] = {});
	const ctx = await browser.newContext(DEVICES[label]);
	const page = await ctx.newPage();
	page.setDefaultTimeout(30000);
	const lines = [];
	page.on('console', (m) => lines.push(`[console.${m.type()}] ${m.text()}`.slice(0, 500)));
	page.on('pageerror', (e) => lines.push(`[pageerror] ${String(e.message).slice(0, 500)}`));
	page.on('response', (resp) => {
		if (resp.status() >= 400) lines.push(`[http ${resp.status()}] ${new URL(resp.url()).pathname}`);
	});

	const login = await ctx.request.post(`${BASE}/api/method/login`, { form: { usr: 'Administrator', pwd: PASSWORD } });
	r.login = login.status();
	say('login status', r.login);

	await page.goto(`${BASE}/app/item`, { waitUntil: 'domcontentloaded' });
	try {
		await page.waitForFunction(() => window.cur_list && cur_list.doctype === 'Item', null, { timeout: 90000 });
		say('item list loaded');
	} catch (e) {
		r.listLoadError = String(e).slice(0, 300);
		say('item list did NOT load', r.listLoadError);
	}
	await sleep(2000);
	await page.screenshot({ path: `${OUT}/${PHASE}-${label}-1-item-list.png` });
	r.listConsole = lines.splice(0).slice(-12);
	say('LIST console', JSON.stringify(r.listConsole));

	// What the browser knows about the Item form and the India Compliance script, before anything is clicked.
	r.diag = await withTimeout(
		page.evaluate(async () => {
			const meta = frappe.get_meta('Item');
			const out = {
				versions: frappe.boot.versions,
				indiaScriptLoaded: typeof gst_settings !== 'undefined' && typeof india_compliance !== 'undefined',
				failing: [],
			};
			const tryEval = (expr) => {
				if (!expr || !/^eval:/.test(expr)) return null;
				try {
					frappe.utils.eval(expr.slice(5), { doc: {}, parent: undefined });
					return null;
				} catch (e) {
					return String(e);
				}
			};
			for (const df of meta.fields) {
				for (const key of ['depends_on', 'mandatory_depends_on', 'read_only_depends_on']) {
					const err = tryEval(df[key]);
					if (err) out.failing.push({ fieldname: df.fieldname, key, expr: df[key], err });
				}
			}
			out.quickEntryFields = meta.fields
				.filter((df) => (df.reqd || df.allow_in_quick_entry) && !df.read_only && !df.is_virtual && df.fieldtype !== 'Tab Break')
				.map((df) => `${df.fieldname}${df.reqd ? '*' : ''}`)
				.join(', ');
			out.hsnCodes = await frappe.xcall('frappe.client.get_count', { doctype: 'GST HSN Code' }).catch((e) => String(e));
			out.gstSettings = await frappe.xcall('frappe.client.get_value', { doctype: 'GST Settings', fieldname: 'validate_hsn_code' }).catch((e) => String(e));
			return out;
		}),
		40000,
		'diag'
	).catch((e) => ({ diagError: String(e).slice(0, 400) }));
	say('DIAG', JSON.stringify(r.diag));
	lines.splice(0);

	const step = async (name, fn, verdict) => {
		let error = null;
		let returned = null;
		try {
			returned = await withTimeout(fn(), 60000, name);
		} catch (e) {
			error = String(e).slice(0, 300);
		}
		await sleep(3000);
		const rec = (r[name] = {
			error,
			returned,
			route: await page.evaluate(() => location.pathname).catch(() => '?'),
			modals: await modals(page).catch(() => ['?']),
			console: lines.splice(0).slice(-40),
		});
		await page.screenshot({ path: `${OUT}/${PHASE}-${label}-${name}.png` }).catch(() => {});
		const text = JSON.stringify(rec);
		const depends = /depends_on/.test(text);
		const ok = !depends && !error && verdict(rec);
		say('STEP', name, JSON.stringify(rec));
		say(`VERDICT ${name}: ${ok ? 'OK' : 'FAIL'}${depends ? ' (depends_on error)' : ''}`);
		await page.evaluate(() => document.querySelectorAll('.modal.show .btn-modal-close, .modal.show .btn-close').forEach((b) => b.click())).catch(() => {});
		await sleep(500);
	};
	const backToList = async () => {
		await page.goto(`${BASE}/app/item`, { waitUntil: 'domcontentloaded' }).catch(() => {});
		await page.waitForFunction(() => window.cur_list && cur_list.doctype === 'Item', null, { timeout: 60000 }).catch(() => {});
		await sleep(1500);
	};
	// frappe.new_doc returns a promise that never settles when the pop-up throws while opening,
	// so race it against a timer in the page.
	const newDoc = (doctype) =>
		page.evaluate(
			(dt) => Promise.race([frappe.new_doc(dt), new Promise((res) => setTimeout(() => res('promise still pending after 10 s: the pop-up did not finish opening'), 10000))]),
			doctype
		);
	const popupOpen = (rec) => rec.modals.some((t) => /New (Item|Customer)/.test(t));

	await step(
		'2-click-add-item',
		() =>
			page.evaluate(() => {
				const b = document.querySelector('.page-actions .primary-action') || document.querySelector('.primary-action');
				if (!b) throw new Error('no primary action button found');
				b.click();
			}),
		popupOpen
	);
	await backToList();
	await step('3-new-doc-item', () => newDoc('Item'), popupOpen);
	await backToList();
	await step('4-control-new-doc-customer', () => newDoc('Customer'), popupOpen);
	await backToList();
	await step(
		'5-full-form-item-new',
		async () => {
			await page.goto(`${BASE}/app/item/new`, { waitUntil: 'domcontentloaded' });
			await page.waitForFunction(() => window.cur_frm && cur_frm.doctype === 'Item', null, { timeout: 30000 });
		},
		(rec) => rec.route.startsWith('/app/item/') && !rec.modals.some((t) => /Invalid/.test(t))
	);
	await backToList();
	await step(
		'6-save-item-through-popup',
		() =>
			page.evaluate(async () => {
				const wait = (ms) => new Promise((res) => setTimeout(res, ms));
				const opened = await Promise.race([frappe.new_doc('Item').then(() => 'opened'), wait(10000).then(() => 'pending')]);
				if (opened === 'pending' || !frappe.quick_entry || !frappe.quick_entry.dialog) return { stage: 'pop-up did not open' };
				const d = frappe.quick_entry.dialog;
				const out = { fields: d.fields_list.map((f) => f.df.fieldname).join(', ') };
				await d.set_value('item_code', 'CI-TEST-ATTA-5KG');
				await d.set_value('item_group', 'Products');
				if (d.get_field('gst_hsn_code')) {
					const hsn = await frappe.xcall('frappe.client.get_list', { doctype: 'GST HSN Code', fields: ['name'], limit_page_length: 1 });
					out.hsn = hsn[0] ? hsn[0].name : null;
					if (hsn[0]) await d.set_value('gst_hsn_code', hsn[0].name);
				}
				d.get_primary_btn().click();
				await wait(7000);
				const found = await frappe.xcall('frappe.client.get_list', { doctype: 'Item', filters: { item_code: 'CI-TEST-ATTA-5KG' }, fields: ['name', 'item_group', 'gst_hsn_code'] });
				out.saved = found;
				return out;
			}),
		(rec) => rec.returned && Array.isArray(rec.returned.saved) && rec.returned.saved.length === 1
	);
	await ctx.close();
}

(async () => {
	fs.mkdirSync(OUT, { recursive: true });
	const browser = await chromium.launch({ channel: 'chrome', args: ['--no-sandbox'] });
	for (const label of SESSIONS) {
		try {
			await session(browser, label);
		} catch (e) {
			results[`${PHASE}/${label}`] = { ...(results[`${PHASE}/${label}`] || {}), fatal: String(e).slice(0, 500) };
			console.log(`[${PHASE}/${label}] FATAL`, String(e).slice(0, 500));
		}
	}
	await browser.close();
	fs.writeFileSync(`${OUT}/results-${PHASE}.json`, JSON.stringify(results, null, 1));
	console.log(`===== DONE ${PHASE} =====`);
})();

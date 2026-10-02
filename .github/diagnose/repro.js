// Opens the throwaway back-office in a real browser and does what the user did:
// click "Add Item" on the Item list (and the same through frappe.new_doc, which is what
// "New Item" in the search bar does). Prints what happened and which Item field expressions
// the browser cannot evaluate. Output also goes to out/ (screenshots and results.json).
const { chromium } = require('playwright-core');
const fs = require('fs');

const BASE = 'http://localhost:8080';
const PASSWORD = process.env.ADMIN_PASSWORD;
const OUT = 'out';
const results = {};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const PHONE = {
	viewport: { width: 412, height: 915 },
	deviceScaleFactor: 2,
	isMobile: true,
	hasTouch: true,
	userAgent:
		'Mozilla/5.0 (Linux; Android 14; SM-S911B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36',
};
const DESKTOP = { viewport: { width: 1280, height: 900 } };

async function modals(page) {
	return page.evaluate(() =>
		[...document.querySelectorAll('.modal.show')].map((el) => el.innerText.replace(/\s+/g, ' ').trim().slice(0, 300))
	);
}

async function session(browser, label, ctxOpts) {
	const r = (results[label] = {});
	const ctx = await browser.newContext(ctxOpts);
	const page = await ctx.newPage();
	const lines = [];
	page.on('console', (m) => lines.push(`[console.${m.type()}] ${m.text()}`.slice(0, 700)));
	page.on('pageerror', (e) => lines.push(`[pageerror] ${String(e.message).slice(0, 700)}`));

	const login = await ctx.request.post(`${BASE}/api/method/login`, { form: { usr: 'Administrator', pwd: PASSWORD } });
	r.login = login.status();

	await page.goto(`${BASE}/app/item`, { waitUntil: 'domcontentloaded' });
	try {
		await page.waitForFunction(() => window.cur_list && cur_list.doctype === 'Item', null, { timeout: 180000 });
	} catch (e) {
		r.listLoadError = String(e).slice(0, 300);
	}
	await sleep(2000);
	await page.screenshot({ path: `${OUT}/${label}-1-item-list.png` });
	r.listConsole = lines.splice(0).slice(-10);

	const step = async (name, fn) => {
		let error = null;
		try {
			await fn();
		} catch (e) {
			error = String(e).slice(0, 300);
		}
		await sleep(3000);
		r[name] = {
			error,
			route: await page.evaluate(() => location.pathname),
			modals: await modals(page),
			console: lines.splice(0).slice(-60),
		};
		await page.screenshot({ path: `${OUT}/${label}-${name}.png` });
		await page.evaluate(() => document.querySelectorAll('.modal.show .btn-modal-close, .modal.show .btn-close').forEach((b) => b.click())).catch(() => {});
		await sleep(500);
	};
	const backToList = async () => {
		await page.goto(`${BASE}/app/item`, { waitUntil: 'domcontentloaded' });
		await page.waitForFunction(() => window.cur_list && cur_list.doctype === 'Item', null, { timeout: 120000 }).catch(() => {});
		await sleep(1500);
	};

	await step('2-click-add-item', () =>
		page.evaluate(() => {
			const b = document.querySelector('.page-actions .primary-action') || document.querySelector('.primary-action');
			if (!b) throw new Error('no primary action button found');
			b.click();
		})
	);
	await backToList();
	await step('3-new-doc-item', () => page.evaluate(() => frappe.new_doc('Item')));
	await backToList();
	await step('4-control-new-doc-customer', () => page.evaluate(() => frappe.new_doc('Customer')));
	await backToList();
	await step('5-full-form-item-new', () => page.goto(`${BASE}/app/item/new`, { waitUntil: 'domcontentloaded' }));

	r.diag = await page
		.evaluate(async () => {
			const meta = frappe.get_meta('Item');
			const out = { version: frappe.boot.versions, quick_entry: meta.quick_entry, evalWorks: null, failing: [], quickEntryFields: [], fieldsWithExpr: 0 };
			try {
				out.evalWorks = new Function('return 1+1')();
			} catch (e) {
				out.evalWorks = String(e);
			}
			const quick = meta.fields.filter((df) => (df.reqd || df.allow_in_quick_entry) && !df.read_only && !df.is_virtual && df.fieldtype !== 'Tab Break');
			out.quickEntryFields = quick.map((df) => [df.fieldname, df.fieldtype, df.reqd ? 'reqd' : '', df.allow_in_quick_entry ? 'quick' : '', df.depends_on || '', df.mandatory_depends_on || '', df.read_only_depends_on || ''].join(' | '));
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
				if (df.depends_on || df.mandatory_depends_on || df.read_only_depends_on) out.fieldsWithExpr += 1;
				for (const key of ['depends_on', 'mandatory_depends_on', 'read_only_depends_on']) {
					const err = tryEval(df[key]);
					if (err) out.failing.push({ fieldname: df.fieldname, key, expr: df[key], err, reqd: df.reqd, quick: df.allow_in_quick_entry });
				}
			}
			out.customFieldsOnItem = await frappe.xcall('frappe.client.get_list', {
				doctype: 'Custom Field',
				filters: { dt: 'Item' },
				fields: ['fieldname', 'fieldtype', 'depends_on', 'mandatory_depends_on', 'read_only_depends_on', 'allow_in_quick_entry', 'module'],
				limit_page_length: 100,
			});
			out.hasItemQuickEntryClass = !!(frappe.ui.form && frappe.ui.form.ItemQuickEntryForm);
			out.itemQuickEntrySource = out.hasItemQuickEntryClass ? frappe.ui.form.ItemQuickEntryForm.toString().slice(0, 7000) : null;
			return out;
		})
		.catch((e) => ({ diagError: String(e).slice(0, 400) }));
	await ctx.close();
}

(async () => {
	const browser = await chromium.launch({ channel: 'chrome', args: ['--no-sandbox'] });
	for (const [label, opts] of [['phone', PHONE], ['desktop', DESKTOP]]) {
		try {
			await session(browser, label, opts);
		} catch (e) {
			results[label] = { ...(results[label] || {}), fatal: String(e).slice(0, 500) };
		}
	}
	await browser.close();
	fs.writeFileSync(`${OUT}/results.json`, JSON.stringify(results, null, 1));
	console.log('===== RESULTS =====');
	console.log(JSON.stringify(results, null, 1));
})();

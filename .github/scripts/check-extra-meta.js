#!/usr/bin/env node
"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "../..");
const extra = require(path.join(root, "zotero/extra-meta/content/extra.js"));
const venues = require(path.join(root, "zotero/extra-meta/content/venues.js"));

// 1. Extra parsing, CRLF, alias cleanup, and non-truncating arXiv rules
assert.equal(extra.getValue("tex.venueabbr: ICML\r\ntex.affiliation: MIT\r\n", "tex.venueabbr"), "ICML");
assert.equal(
	extra.setValue("tex.venueabbr: ICML\r\ntex.affiliation: MIT\r\n", "tex.venueabbr", "NeurIPS"),
	"tex.venueabbr: NeurIPS\ntex.affiliation: MIT\n"
);
assert.equal(
	extra.setValue("tex.openreview: https://openreview.net/forum?id=old123", "OpenReview", "", (p) => p.normalizedKey === "tex.openreview"),
	""
);
assert.equal(
	extra.setValue("Number: 12\nNumber: arXiv:2501.00001", "arXiv", "", (p) => p.normalizedKey === "number" && /^arXiv:/i.test(p.value)),
	"Number: 12"
);

assert.equal(extra.normalizeOpenReviewInput("AbCdEf1234"), "https://openreview.net/forum?id=AbCdEf1234");
assert.equal(extra.normalizeOpenReviewInput("openreview.net/pdf?id=AbCdEf&noteId=XyZ"), "https://openreview.net/forum?id=AbCdEf&noteId=XyZ");
assert.equal(extra.normalizeOpenReviewInput("https://example.com/forum?id=AbCdEf"), "");

assert.deepEqual(extra.parseArxiv("2301.123456"), {
	id: "2301.123456",
	category: "",
	url: "",
	raw: "2301.123456",
});
assert.deepEqual(extra.parseArxiv("2301.12345 trailing note"), {
	id: "2301.12345 trailing note",
	category: "",
	url: "",
	raw: "2301.12345 trailing note",
});
assert.deepEqual(extra.parseArxiv("https://arxiv.org/html/2501.00001v1/"), {
	id: "2501.00001v1",
	category: "",
	url: "https://arxiv.org/abs/2501.00001v1",
	raw: "https://arxiv.org/html/2501.00001v1/",
});
assert.deepEqual(extra.parseArxiv("https://arxiv.org/abs/not/an/id"), {
	id: "https://arxiv.org/abs/not/an/id",
	category: "",
	url: "",
	raw: "https://arxiv.org/abs/not/an/id",
});
assert.equal(extra.normalizeArxivInput("https://export.arxiv.org/pdf/2501.00001v2.pdf"), "2501.00001v2");

const encoded = extra.encodeLinks("tex.sourcecode: https://github.com/org/repo?a=1 | b=2\ntex.openreview: AbCdEf1234");
const decoded = extra.decodeLinks(encoded);
assert.equal(decoded.length, 2);
assert.equal(decoded[0].icon, "github");
assert.equal(decoded[1].url, "https://openreview.net/forum?id=AbCdEf1234");
assert.equal(extra.encodeLinks(""), "");

// 2. Venue tone matching
assert.equal(venues.resolveTone("ICRA'24"), "orange");
assert.equal(venues.resolveTone("NeurIPS '25 Workshop"), "purple");
assert.equal(venues.resolveTone("RA-L 2024"), "gold");

// 3. Sandboxed main.js checks (window isolation, mixed batch edit, undoAction, keyboard isolation)
function makeFakeElement(tag) {
	const listeners = new Map();
	return {
		tagName: tag,
		attributes: {},
		dataset: {},
		children: [],
		placeholder: "",
		textContent: "",
		setAttribute(k, v) {
			this.attributes[k] = String(v);
		},
		appendChild(child) {
			this.children.push(child);
			return child;
		},
		addEventListener(type, fn) {
			if (!listeners.has(type)) {
				listeners.set(type, []);
			}
			listeners.get(type).push(fn);
		},
		dispatch(type, event) {
			for (const fn of listeners.get(type) || []) {
				fn(event);
			}
		},
	};
}

function makeItem(id, extraText) {
	const saves = [];
	return {
		id,
		extra: extraText,
		saves,
		isRegularItem: () => true,
		isEditable: () => true,
		getField: (name) => (name === "extra" ? extraText : ""),
		setField: (name, val) => {
			if (name === "extra") {
				extraText = val;
			}
		},
		save: async (opts) => {
			saves.push(opts);
		},
	};
}

async function runMainTests() {
	const columns = [];
	const rows = [];
	const launchedUrls = [];
	const refreshCalls = [];

	const itemA = makeItem(1, "tex.venueabbr: ICML\ntex.openreview: https://openreview.net/forum?id=abc123\nNumber: 12\nNumber: arXiv:2501.00001");
	const itemB = makeItem(2, "tex.venueabbr: NeurIPS");
	const itemC = makeItem(3, "tex.venueabbr: NeurIPS");

	const valueElems = new Map();
	function makeBox(item, extraItems) {
		return {
			item,
			extraItems,
			isConnected: true,
			querySelector(sel) {
				const match = /data-custom-row-id="([^"]+)"/.exec(sel);
				if (!match) {
					return null;
				}
				const key = match[1];
				if (!valueElems.has(key)) {
					valueElems.set(key, makeFakeElement("editable-text"));
				}
				return valueElems.get(key);
			},
		};
	}

	let activeBox = makeBox(itemA, []);
	const secondaryWindowBox = makeBox(itemA, [itemC]);

	const sandbox = {
		ExtraMetaExtra: extra,
		ExtraMetaVenues: venues,
		CSS: { escape: (s) => s },
		Localization: function () {
			this.formatValueSync = (id) => ({
				"extra-meta-col-venue": "会议/期刊",
				"extra-meta-row-venue": "会议/期刊",
				"extra-meta-row-openreview": "OpenReview",
				"extra-meta-row-arxiv": "arXiv",
			}[id] || "");
		},
		Zotero: {
			launchURL: (url) => launchedUrls.push(url),
			logError: (err) => { throw err; },
			getString: (id) => (id === "item-pane-batch-editing-multiple-values-placeholder" ? "Multiple" : id),
			getMainWindow: () => ({ ZoteroPane: { itemPane: { querySelector: () => activeBox } } }),
			getMainWindows: () => [
				{ document: { querySelectorAll: () => [secondaryWindowBox] } },
				{ document: { querySelectorAll: () => [activeBox] } },
			],
			DB: { executeTransaction: async (fn) => fn() },
			ItemTreeManager: { registerColumn: (col) => columns.push(col) },
			ItemPaneManager: {
				registerInfoRow: (row) => {
					rows.push({ ...row, rowID: `extra-meta@dotfiles.local-${row.rowID}` });
				},
				refreshInfoRow: (id) => refreshCalls.push(id),
			},
		},
	};
	vm.createContext(sandbox);
	vm.runInContext(fs.readFileSync(path.join(root, "zotero/extra-meta/content/main.js"), "utf8"), sandbox);
	sandbox.ExtraMetaMain.init({ pluginID: "extra-meta@dotfiles.local" });

	assert.equal(columns[0].label, "会议/期刊");

	// Keyboard isolation on cell buttons
	const fakeDoc = { createElementNS: (_ns, tag) => makeFakeElement(tag) };
	const arxivCol = columns.find((c) => c.dataKey === "arxiv");
	const cell = arxivCol.renderCell(0, "2501.00001", {}, false, fakeDoc);
	const button = cell.children[0];
	let stopped = false;
	let prevented = false;
	button.dispatch("keydown", {
		key: "Enter",
		stopPropagation: () => { stopped = true; },
		preventDefault: () => { prevented = true; },
	});
	assert.equal(stopped, true);
	assert.equal(prevented, true);
	assert.deepEqual(launchedUrls, ["https://arxiv.org/abs/2501.00001"]);

	let tabStopped = false;
	button.dispatch("keydown", {
		key: "Tab",
		stopPropagation: () => { tabStopped = true; },
		preventDefault: () => {},
	});
	assert.equal(tabStopped, false);

	// First-column cells include .cell-text so Zotero preserves button listeners
	const firstVenueCell = columns.find((c) => c.dataKey === "venue").renderCell(0, "CoRL", {}, true, fakeDoc);
	assert.match(firstVenueCell.children[0].className, /\bcell-text\b/);
	assert.equal(firstVenueCell.children[0].children[0].className, "em-venue-badge");

	const firstArxivCell = arxivCol.renderCell(0, "2501.00001", {}, true, fakeDoc);
	assert.match(firstArxivCell.children[0].className, /\bcell-text\b/);
	assert.equal(firstArxivCell.children[0].children[0].tagName, "button");

	// Active window isolation: editing itemA in activeBox must NOT modify itemC in secondaryWindowBox
	const venueRow = rows.find((r) => r.rowID.endsWith("em-venue"));
	assert.equal(venueRow.onGetData({ rowID: venueRow.rowID, item: itemA, tabType: "library" }), "ICML");
	venueRow.onSetData({ rowID: venueRow.rowID, item: itemA, tabType: "library", value: "ICLR" });
	await new Promise((r) => setImmediate(r));
	assert.equal(extra.getValue(itemA.getField("extra"), "tex.venueabbr"), "ICLR");
	assert.equal(extra.getValue(itemC.getField("extra"), "tex.venueabbr"), "NeurIPS");
	assert.deepEqual(JSON.parse(JSON.stringify(itemA.saves[0])), {
		undoAction: "undo-action-edit-field",
		undoActionArgs: { field: "会议/期刊", count: 1 },
	});

	// Clearing OpenReview and arXiv aliases leaves Number: 12 intact
	const openReviewRow = rows.find((r) => r.rowID.endsWith("em-openreview"));
	openReviewRow.onSetData({ rowID: openReviewRow.rowID, item: itemA, tabType: "library", value: "" });
	await new Promise((r) => setImmediate(r));
	assert.equal(openReviewRow.onGetData({ rowID: openReviewRow.rowID, item: itemA, tabType: "library" }), "");

	const arxivRow = rows.find((r) => r.rowID.endsWith("em-arxiv"));
	arxivRow.onSetData({ rowID: arxivRow.rowID, item: itemA, tabType: "library", value: "" });
	await new Promise((r) => setImmediate(r));
	assert.equal(arxivRow.onGetData({ rowID: arxivRow.rowID, item: itemA, tabType: "library" }), "");
	assert.equal(extra.getValue(itemA.getField("extra"), "Number"), "12");

	// Mixed batch editing: blur without edit preserves values; Backspace + blur clears all items
	activeBox = makeBox(itemA, [itemB]);
	assert.equal(venueRow.onGetData({ rowID: venueRow.rowID, item: itemA, tabType: "library" }), "");
	const venueElem = valueElems.get(venueRow.rowID);
	assert.equal(venueElem.placeholder, "Multiple");

	venueRow.onSetData({ rowID: venueRow.rowID, item: itemA, tabType: "library", value: "" });
	await new Promise((r) => setImmediate(r));
	assert.equal(extra.getValue(itemA.getField("extra"), "tex.venueabbr"), "ICLR");
	assert.equal(extra.getValue(itemB.getField("extra"), "tex.venueabbr"), "NeurIPS");

	venueElem.dispatch("keydown", { key: "Backspace" });
	assert.equal(venueElem.placeholder, "");
	venueRow.onSetData({ rowID: venueRow.rowID, item: itemA, tabType: "library", value: "" });
	await new Promise((r) => setImmediate(r));
	assert.equal(extra.getValue(itemA.getField("extra"), "tex.venueabbr"), "");
	assert.equal(extra.getValue(itemB.getField("extra"), "tex.venueabbr"), "");
}

runMainTests()
	.then(() => console.log("ok       Extra Meta: extra parser, venue tones, batch editing, aliases and keyboard isolation"))
	.catch((err) => {
		console.error(err);
		process.exit(1);
	});

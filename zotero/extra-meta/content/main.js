/*
 * Registers Extra Meta columns in the item list and editable rows in Info.
 */

/* global Zotero, Localization, ExtraMetaExtra, ExtraMetaVenues */

var ExtraMetaMain = (function () {
	"use strict";

	const HTML_NS = "http://www.w3.org/1999/xhtml";
	const SVG_NS = "http://www.w3.org/2000/svg";
	const STYLE_ID = "extra-meta-styles";
	const STYLE_URI = "chrome://extra-meta/content/styles.css";
	const FTL_FILE = "extra-meta.ftl";

	const SVG_ICONS = {
		github: [
			["path", {
				fill: "currentColor",
				"fill-rule": "evenodd",
				"clip-rule": "evenodd",
				d: "M8 1.5a6.5 6.5 0 0 0-2.055 12.667c.325.06.444-.141.444-.313 0-.154-.006-.563-.009-1.105-1.805.392-2.186-.87-2.186-.87-.295-.75-.72-.95-.72-.95-.589-.402.045-.394.045-.394.651.046.994.668.994.668.579.992 1.519.705 1.889.539.059-.419.227-.705.412-.867-1.441-.164-2.957-.72-2.957-3.208 0-.709.253-1.288.668-1.742-.067-.164-.29-.824.063-1.718 0 0 .545-.175 1.787.665a6.22 6.22 0 0 1 3.254 0c1.241-.84 1.785-.665 1.785-.665.354.894.131 1.554.064 1.718.416.454.667 1.033.667 1.742 0 2.494-1.518 3.042-2.964 3.203.233.2.441.596.441 1.201 0 .867-.008 1.566-.008 1.779 0 .173.117.376.447.312A6.5 6.5 0 0 0 8 1.5Z",
			}],
		],
		code: [
			["path", {
				d: "M5.5 4.5 2 8l3.5 3.5M10.5 4.5 14 8l-3.5 3.5",
				stroke: "currentColor",
				"stroke-width": "1.5",
				"stroke-linecap": "round",
				"stroke-linejoin": "round",
			}],
			["path", {
				d: "M9 3.5 7 12.5",
				stroke: "currentColor",
				"stroke-width": "1.4",
				"stroke-linecap": "round",
			}],
		],
		review: [
			["path", {
				d: "M3 2.5h10A1.5 1.5 0 0 1 14.5 4v6a1.5 1.5 0 0 1-1.5 1.5H6.8L3.5 14v-2.5H3A1.5 1.5 0 0 1 1.5 10V4A1.5 1.5 0 0 1 3 2.5Z",
				stroke: "currentColor",
				"stroke-width": "1.35",
				"stroke-linejoin": "round",
			}],
			["path", {
				d: "M5 5.8h6M5 8.3h4",
				stroke: "currentColor",
				"stroke-width": "1.35",
				"stroke-linecap": "round",
			}],
		],
		globe: [
			["circle", { cx: "8", cy: "8", r: "5.75", stroke: "currentColor", "stroke-width": "1.35" }],
			["ellipse", { cx: "8", cy: "8", rx: "2.6", ry: "5.75", stroke: "currentColor", "stroke-width": "1.2" }],
			["path", { d: "M2.5 8h11", stroke: "currentColor", "stroke-width": "1.2" }],
		],
	};

	const INFO_FIELDS = [
		{ id: "venue", key: "tex.venueabbr", l10nID: "extra-meta-row-venue", fallbackLabel: "Venue" },
		{ id: "affiliation", key: "tex.affiliation", l10nID: "extra-meta-row-affiliation", fallbackLabel: "Affiliation" },
		{ id: "sourcecode", key: "tex.sourcecode", l10nID: "extra-meta-row-sourcecode", fallbackLabel: "Source Code" },
		{ id: "projecturl", key: "tex.projecturl", l10nID: "extra-meta-row-projecturl", fallbackLabel: "Project URL" },
		{
			id: "openreview",
			key: "OpenReview",
			l10nID: "extra-meta-row-openreview",
			fallbackLabel: "OpenReview",
			getValue: (extra) => ExtraMetaExtra.getValue(extra, "OpenReview") || ExtraMetaExtra.getValue(extra, "tex.openreview"),
			isAliasLine: (parsed) => parsed.normalizedKey === "tex.openreview",
			normalize: (val) => {
				if (!val) {
					return "";
				}
				return ExtraMetaExtra.normalizeOpenReviewInput(val) || null;
			},
		},
		{
			id: "arxiv",
			key: "arXiv",
			l10nID: "extra-meta-row-arxiv",
			fallbackLabel: "arXiv",
			getValue: (extra) => ExtraMetaExtra.formatArxivData(extra),
			isAliasLine: (parsed) => parsed.normalizedKey === "number" && /^arXiv:/i.test(parsed.value),
			normalize: (val) => ExtraMetaExtra.normalizeArxivInput(val),
		},
	];

	let pluginID = null;
	let strings = null;
	const registeredColumnIDs = [];
	const registeredRowIDs = [];
	const boundValueElements = new WeakSet();
	const dirtyValueElements = new WeakSet();

	function getL10nString(id, fallback) {
		if (!strings && typeof Localization === "function") {
			try {
				strings = new Localization([FTL_FILE], true);
			}
			catch {
				strings = null;
			}
		}
		try {
			return strings?.formatValueSync(id) || fallback;
		}
		catch {
			return fallback;
		}
	}

	function getMixedPlaceholder() {
		try {
			return Zotero.getString("item-pane-batch-editing-multiple-values-placeholder") || "Multiple";
		}
		catch {
			return "Multiple";
		}
	}

	function isEligibleItem(item) {
		return Boolean(
			item
			&& typeof item.isRegularItem === "function"
			&& item.isRegularItem()
			&& !item.isFeedItem
		);
	}

	function isEditableItem(item) {
		if (!isEligibleItem(item)) {
			return false;
		}
		if (typeof item.isEditable === "function") {
			return Boolean(item.isEditable());
		}
		return Boolean(Zotero.Libraries?.get?.(item.libraryID)?.editable);
	}

	function getItemField(item, fieldName) {
		if (!isEligibleItem(item)) {
			return "";
		}
		try {
			return item.getField(fieldName) || "";
		}
		catch (e) {
			Zotero.logError(e);
			return "";
		}
	}

	function getExtraString(item) {
		return getItemField(item, "extra");
	}

	function createHtml(doc, tag, className) {
		const el = doc.createElementNS(HTML_NS, tag);
		if (className) {
			el.className = className;
		}
		return el;
	}

	function createCell(doc, column, extraClass, isFirstColumn) {
		if (!isFirstColumn) {
			const cell = createHtml(doc, "span", `cell ${column.className || ""} em-cell ${extraClass}`);
			return { cell, container: cell };
		}
		// Zotero wraps first-column cells lacking .cell-text via innerHTML, which
		// would drop button listeners and replace flex centering on the cell.
		const cell = createHtml(doc, "span", `cell ${column.className || ""} em-cell`);
		const container = createHtml(doc, "span", `cell-text em-cell-content ${extraClass}`);
		cell.appendChild(container);
		return { cell, container };
	}

	function createSvgIcon(doc, kind) {
		const svg = doc.createElementNS(SVG_NS, "svg");
		svg.setAttribute("viewBox", "0 0 16 16");
		svg.setAttribute("fill", "none");
		svg.setAttribute("aria-hidden", "true");
		svg.setAttribute("class", "em-link-icon");

		for (const [tag, attrs] of SVG_ICONS[kind] || SVG_ICONS.globe) {
			const child = doc.createElementNS(SVG_NS, tag);
			for (const [name, value] of Object.entries(attrs)) {
				child.setAttribute(name, value);
			}
			svg.appendChild(child);
		}
		return svg;
	}

	function stopEvent(event) {
		event.stopPropagation();
	}

	function openExternalUrl(url) {
		try {
			Zotero.launchURL(url);
		}
		catch (e) {
			Zotero.logError(e);
		}
	}

	function attachExternalUrlAction(button, url) {
		button.addEventListener("mousedown", stopEvent);
		button.addEventListener("mouseup", stopEvent);
		button.addEventListener("dblclick", stopEvent);
		button.addEventListener("click", (event) => {
			event.stopPropagation();
			event.preventDefault();
			openExternalUrl(url);
		});
		button.addEventListener("keydown", (event) => {
			if (event.key === "Enter" || event.key === " ") {
				event.preventDefault();
				event.stopPropagation();
				openExternalUrl(url);
				return;
			}
			if (event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey) {
				event.stopPropagation();
			}
		});
	}

	function createExternalButton(doc, className, tooltip, url) {
		const button = createHtml(doc, "button", className);
		button.setAttribute("type", "button");
		button.setAttribute("title", tooltip);
		button.setAttribute("aria-label", tooltip);
		attachExternalUrlAction(button, url);
		return button;
	}

	function renderVenueCell(index, data, column, isFirstColumn, doc) {
		const { cell, container } = createCell(doc, column, "em-venue-cell", isFirstColumn);
		const value = String(data || "").trim();
		if (!value) {
			return cell;
		}
		const badge = createHtml(doc, "span", "em-venue-badge");
		badge.dataset.tone = ExtraMetaVenues.resolveTone(value);
		badge.setAttribute("title", value);
		badge.textContent = value;
		container.appendChild(badge);
		return cell;
	}

	function renderAffiliationCell(index, data, column, isFirstColumn, doc) {
		const { cell, container } = createCell(doc, column, "em-affil-cell", isFirstColumn);
		const value = String(data || "").trim();
		if (!value) {
			return cell;
		}
		cell.setAttribute("title", value);
		const text = createHtml(doc, "span", "em-affil-text");
		text.textContent = value;
		container.appendChild(text);
		return cell;
	}

	function renderLinksCell(index, data, column, isFirstColumn, doc) {
		const { cell, container } = createCell(doc, column, "em-links-cell", isFirstColumn);
		for (const link of ExtraMetaExtra.decodeLinks(data)) {
			const button = createExternalButton(doc, `em-link-btn em-link-${link.kind}`, link.tooltip, link.url);
			button.appendChild(createSvgIcon(doc, link.icon));
			container.appendChild(button);
		}
		return cell;
	}

	function renderArxivCell(index, data, column, isFirstColumn, doc) {
		const { cell, container } = createCell(doc, column, "em-arxiv-cell", isFirstColumn);
		const parsed = ExtraMetaExtra.parseArxiv(data);
		if (!parsed) {
			return cell;
		}
		if (!parsed.url) {
			const plain = createHtml(doc, "span", "em-arxiv-text");
			plain.textContent = parsed.id;
			plain.setAttribute("title", parsed.raw);
			container.appendChild(plain);
			return cell;
		}
		const tooltip = parsed.category
			? `arXiv:${parsed.id} [${parsed.category}] — Open on arXiv`
			: `arXiv:${parsed.id} — Open on arXiv`;
		const button = createExternalButton(doc, "em-arxiv-btn", tooltip, parsed.url);
		const label = createHtml(doc, "span", "em-arxiv-label");
		label.textContent = parsed.id;
		button.appendChild(label);
		container.appendChild(button);
		return cell;
	}

	function registerColumns() {
		const specs = [
			{
				dataKey: "venue",
				label: getL10nString("extra-meta-col-venue", "Venue"),
				width: "96",
				minWidth: 64,
				dataProvider: (item) => ExtraMetaExtra.getValue(getExtraString(item), "tex.venueabbr"),
				renderCell: renderVenueCell,
			},
			{
				dataKey: "affiliation",
				label: getL10nString("extra-meta-col-affiliation", "Affiliation"),
				flex: 2,
				minWidth: 90,
				dataProvider: (item) => ExtraMetaExtra.getValue(getExtraString(item), "tex.affiliation"),
				renderCell: renderAffiliationCell,
			},
			{
				dataKey: "links",
				label: getL10nString("extra-meta-col-links", "Links"),
				width: "90",
				minWidth: 54,
				dataProvider: (item) => ExtraMetaExtra.encodeLinks(getExtraString(item), getItemField(item, "url")),
				renderCell: renderLinksCell,
			},
			{
				dataKey: "arxiv",
				label: getL10nString("extra-meta-col-arxiv", "arXiv"),
				width: "98",
				minWidth: 74,
				dataProvider: (item) => ExtraMetaExtra.formatArxivData(getExtraString(item)),
				renderCell: renderArxivCell,
			},
		];

		for (const spec of specs) {
			try {
				const reg = Zotero.ItemTreeManager.registerColumn({
					...spec,
					pluginID,
					enabledTreeIDs: ["main"],
					zoteroPersist: ["width", "hidden", "sortDirection"],
				});
				if (reg && typeof reg.then === "function") {
					reg.then((colID) => {
						if (colID) {
							registeredColumnIDs.push(colID);
						}
					}).catch((e) => Zotero.logError(e));
				}
				else if (reg) {
					registeredColumnIDs.push(reg);
				}
			}
			catch (e) {
				Zotero.logError(e);
			}
		}
	}

	function activeInfoBox(item, tabType) {
		if (!item || (tabType && tabType !== "library")) {
			return null;
		}
		const box = Zotero.getMainWindow?.()?.ZoteroPane?.itemPane?.querySelector("info-box");
		if (box && box.isConnected !== false && box.item && box.item.id === item.id) {
			return box;
		}
		return null;
	}

	function editedItems(item, tabType) {
		if (!item) {
			return [];
		}
		const box = activeInfoBox(item, tabType);
		if (box && Array.isArray(box.extraItems) && box.extraItems.length) {
			return [box.item, ...box.extraItems];
		}
		return [item];
	}

	function getRowValueElement(box, rowID) {
		if (!box || !rowID) {
			return null;
		}
		const escaped = typeof CSS !== "undefined" && typeof CSS.escape === "function"
			? CSS.escape(rowID)
			: rowID;
		return box.querySelector(`.meta-row[data-custom-row-id="${escaped}"] .custom-row-value`);
	}

	function bindValueElement(valueElem) {
		if (!valueElem || boundValueElements.has(valueElem)) {
			return;
		}
		boundValueElements.add(valueElem);
		valueElem.addEventListener("input", () => {
			dirtyValueElements.add(valueElem);
		});
		valueElem.addEventListener("keydown", (event) => {
			if ((event.key === "Backspace" || event.key === "Delete") && valueElem.placeholder) {
				dirtyValueElements.add(valueElem);
				valueElem.placeholder = "";
			}
			else if (event.key === "Escape") {
				dirtyValueElements.delete(valueElem);
			}
		});
	}

	function readFieldValue(item, field) {
		const extra = getExtraString(item);
		return field.getValue ? field.getValue(extra) : ExtraMetaExtra.getValue(extra, field.key);
	}

	function sharedFieldState(items, field) {
		const eligible = items.filter(isEligibleItem);
		if (!eligible.length) {
			return { value: "", mixed: false };
		}
		const first = readFieldValue(eligible[0], field);
		for (let i = 1; i < eligible.length; i++) {
			if (readFieldValue(eligible[i], field) !== first) {
				return { value: "", mixed: true };
			}
		}
		return { value: first, mixed: false };
	}

	async function writeFieldValue(items, field, value) {
		const pending = [];
		for (const item of items) {
			if (!isEditableItem(item)) {
				continue;
			}
			const current = item.getField("extra") || "";
			const updated = ExtraMetaExtra.setValue(current, field.key, value, field.isAliasLine);
			if (updated !== current) {
				pending.push({ item, updated });
			}
		}
		if (!pending.length) {
			return;
		}
		const saveOptions = {
			undoAction: "undo-action-edit-field",
			undoActionArgs: {
				field: getL10nString(field.l10nID, field.fallbackLabel),
				count: pending.length,
			},
		};
		await Zotero.DB.executeTransaction(async () => {
			for (const { item, updated } of pending) {
				item.setField("extra", updated);
				await item.save(saveOptions);
			}
		});
	}

	function registerInfoRows() {
		for (const field of INFO_FIELDS) {
			try {
				const regID = Zotero.ItemPaneManager.registerInfoRow({
					rowID: `em-${field.id}`,
					pluginID,
					label: { l10nID: field.l10nID },
					position: "end",
					multiline: false,
					nowrap: false,
					editable: true,
					onGetData: ({ rowID: id, item, tabType }) => {
						const state = sharedFieldState(editedItems(item, tabType), field);
						const valueElem = getRowValueElement(activeInfoBox(item, tabType), id);
						if (valueElem) {
							bindValueElement(valueElem);
							dirtyValueElements.delete(valueElem);
							valueElem.placeholder = state.mixed ? getMixedPlaceholder() : "";
						}
						return state.value;
					},
					onSetData: ({ rowID: id, item, tabType, value }) => {
						const box = activeInfoBox(item, tabType);
						const valueElem = getRowValueElement(box, id);
						const edited = valueElem ? dirtyValueElements.delete(valueElem) : false;
						const items = editedItems(item, tabType);
						const state = sharedFieldState(items, field);
						const rawClean = ExtraMetaExtra.sanitizeValue(value);
						const clean = field.normalize ? field.normalize(rawClean) : rawClean;
						if (clean === null) {
							Zotero.ItemPaneManager.refreshInfoRow(id);
							return;
						}
						if (state.mixed && clean === "" && !edited) {
							if (valueElem) {
								valueElem.placeholder = getMixedPlaceholder();
							}
							return;
						}
						if (!state.mixed && clean === state.value) {
							if (clean !== value) {
								Zotero.ItemPaneManager.refreshInfoRow(id);
							}
							return;
						}
						writeFieldValue(items, field, clean)
							.then(() => {
								if (clean !== value || state.mixed) {
									Zotero.ItemPaneManager.refreshInfoRow(id);
								}
							})
							.catch((e) => {
								Zotero.logError(e);
								Zotero.ItemPaneManager.refreshInfoRow(id);
							});
					},
					onItemChange: ({ item, setEnabled, setEditable }) => {
						const eligible = isEligibleItem(item);
						setEnabled(eligible);
						setEditable(isEditableItem(item));
					},
				});
				if (regID) {
					registeredRowIDs.push(regID);
				}
			}
			catch (e) {
				Zotero.logError(e);
			}
		}
	}

	function addToWindow(win) {
		win.MozXULElement.insertFTLIfNeeded(FTL_FILE);
		const doc = win.document;
		if (!doc.getElementById(STYLE_ID)) {
			const link = doc.createElementNS(HTML_NS, "link");
			link.id = STYLE_ID;
			link.rel = "stylesheet";
			link.href = STYLE_URI;
			doc.documentElement.appendChild(link);
		}
	}

	function removeFromWindow(win) {
		const doc = win.document;
		doc.querySelector(`link[href="${FTL_FILE}"]`)?.remove();
		doc.getElementById(STYLE_ID)?.remove();
	}

	function destroy() {
		while (registeredColumnIDs.length) {
			const id = registeredColumnIDs.pop();
			try {
				Zotero.ItemTreeManager?.unregisterColumn?.(id);
			}
			catch (e) {
				Zotero.logError(e);
			}
		}
		while (registeredRowIDs.length) {
			const id = registeredRowIDs.pop();
			try {
				Zotero.ItemPaneManager?.unregisterInfoRow?.(id);
			}
			catch (e) {
				Zotero.logError(e);
			}
		}
	}

	function init(options) {
		pluginID = options.pluginID;
		registerColumns();
		registerInfoRows();
	}

	return { init, destroy, addToWindow, removeFromWindow };
})();

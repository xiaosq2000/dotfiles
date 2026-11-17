/*
 * Registers Extra Meta columns in the item list and editable rows in Info.
 */

/* global Zotero, ExtraMetaExtra, ExtraMetaVenues */

var ExtraMetaMain = (function () {
	"use strict";

	const HTML_NS = "http://www.w3.org/1999/xhtml";
	const SVG_NS = "http://www.w3.org/2000/svg";
	const STYLE_ID = "extra-meta-styles";
	const STYLE_URI = "chrome://extra-meta/content/styles.css";
	const FTL_FILE = "extra-meta.ftl";

	const INFO_FIELDS = [
		{ id: "venue", key: "tex.venueabbr", l10nID: "extra-meta-row-venue" },
		{ id: "affiliation", key: "tex.affiliation", l10nID: "extra-meta-row-affiliation" },
		{ id: "sourcecode", key: "tex.sourcecode", l10nID: "extra-meta-row-sourcecode" },
		{ id: "projecturl", key: "tex.projecturl", l10nID: "extra-meta-row-projecturl" },
		{
			id: "openreview",
			key: "OpenReview",
			l10nID: "extra-meta-row-openreview",
			getValue: (extra) => ExtraMetaExtra.getValue(extra, "OpenReview") || ExtraMetaExtra.getValue(extra, "tex.openreview"),
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
			getValue: (extra) => ExtraMetaExtra.formatArxivData(extra),
			normalize: (val) => ExtraMetaExtra.normalizeArxivInput(val),
		},
	];

	let pluginID = null;
	let registeredColumns = [];
	let registeredRows = [];

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

	function createSvgIcon(doc, kind) {
		const svg = doc.createElementNS(SVG_NS, "svg");
		svg.setAttribute("viewBox", "0 0 16 16");
		svg.setAttribute("fill", "none");
		svg.setAttribute("aria-hidden", "true");
		svg.setAttribute("class", "em-link-icon");

		if (kind === "github") {
			const path = doc.createElementNS(SVG_NS, "path");
			path.setAttribute("fill", "currentColor");
			path.setAttribute("fill-rule", "evenodd");
			path.setAttribute("clip-rule", "evenodd");
			path.setAttribute(
				"d",
				"M8 1.5a6.5 6.5 0 0 0-2.055 12.667c.325.06.444-.141.444-.313 0-.154-.006-.563-.009-1.105-1.805.392-2.186-.87-2.186-.87-.295-.75-.72-.95-.72-.95-.589-.402.045-.394.045-.394.651.046.994.668.994.668.579.992 1.519.705 1.889.539.059-.419.227-.705.412-.867-1.441-.164-2.957-.72-2.957-3.208 0-.709.253-1.288.668-1.742-.067-.164-.29-.824.063-1.718 0 0 .545-.175 1.787.665a6.22 6.22 0 0 1 3.254 0c1.241-.84 1.785-.665 1.785-.665.354.894.131 1.554.064 1.718.416.454.667 1.033.667 1.742 0 2.494-1.518 3.042-2.964 3.203.233.2.441.596.441 1.201 0 .867-.008 1.566-.008 1.779 0 .173.117.376.447.312A6.5 6.5 0 0 0 8 1.5Z"
			);
			svg.appendChild(path);
			return svg;
		}

		if (kind === "code") {
			const p1 = doc.createElementNS(SVG_NS, "path");
			p1.setAttribute("d", "M5.5 4.5 2 8l3.5 3.5M10.5 4.5 14 8l-3.5 3.5");
			p1.setAttribute("stroke", "currentColor");
			p1.setAttribute("stroke-width", "1.5");
			p1.setAttribute("stroke-linecap", "round");
			p1.setAttribute("stroke-linejoin", "round");
			const p2 = doc.createElementNS(SVG_NS, "path");
			p2.setAttribute("d", "M9 3.5 7 12.5");
			p2.setAttribute("stroke", "currentColor");
			p2.setAttribute("stroke-width", "1.4");
			p2.setAttribute("stroke-linecap", "round");
			svg.append(p1, p2);
			return svg;
		}

		if (kind === "review") {
			const bubble = doc.createElementNS(SVG_NS, "path");
			bubble.setAttribute(
				"d",
				"M3 2.5h10A1.5 1.5 0 0 1 14.5 4v6a1.5 1.5 0 0 1-1.5 1.5H6.8L3.5 14v-2.5H3A1.5 1.5 0 0 1 1.5 10V4A1.5 1.5 0 0 1 3 2.5Z"
			);
			bubble.setAttribute("stroke", "currentColor");
			bubble.setAttribute("stroke-width", "1.35");
			bubble.setAttribute("stroke-linejoin", "round");
			const lines = doc.createElementNS(SVG_NS, "path");
			lines.setAttribute("d", "M5 5.8h6M5 8.3h4");
			lines.setAttribute("stroke", "currentColor");
			lines.setAttribute("stroke-width", "1.35");
			lines.setAttribute("stroke-linecap", "round");
			svg.append(bubble, lines);
			return svg;
		}

		// Globe / project page icon
		const circle = doc.createElementNS(SVG_NS, "circle");
		circle.setAttribute("cx", "8");
		circle.setAttribute("cy", "8");
		circle.setAttribute("r", "5.75");
		circle.setAttribute("stroke", "currentColor");
		circle.setAttribute("stroke-width", "1.35");
		const meridian = doc.createElementNS(SVG_NS, "ellipse");
		meridian.setAttribute("cx", "8");
		meridian.setAttribute("cy", "8");
		meridian.setAttribute("rx", "2.6");
		meridian.setAttribute("ry", "5.75");
		meridian.setAttribute("stroke", "currentColor");
		meridian.setAttribute("stroke-width", "1.2");
		const equator = doc.createElementNS(SVG_NS, "path");
		equator.setAttribute("d", "M2.5 8h11");
		equator.setAttribute("stroke", "currentColor");
		equator.setAttribute("stroke-width", "1.2");
		svg.append(circle, meridian, equator);
		return svg;
	}

	function attachExternalUrlAction(button, url) {
		const stop = (event) => event.stopPropagation();
		button.addEventListener("mousedown", stop);
		button.addEventListener("mouseup", stop);
		button.addEventListener("dblclick", stop);
		button.addEventListener("click", (event) => {
			event.stopPropagation();
			event.preventDefault();
			try {
				Zotero.launchURL(url);
			}
			catch (e) {
				Zotero.logError(e);
			}
		});
	}

	function renderVenueCell(index, data, column, isFirstColumn, doc) {
		const cell = createHtml(doc, "span", `cell ${column.className || ""} em-cell em-venue-cell`);
		const value = String(data || "").trim();
		if (!value) {
			return cell;
		}
		const badge = createHtml(doc, "span", "em-venue-badge");
		badge.dataset.tone = ExtraMetaVenues.resolveTone(value);
		badge.setAttribute("title", value);
		const label = createHtml(doc, "span", "em-badge-text");
		label.textContent = value;
		badge.appendChild(label);
		cell.appendChild(badge);
		return cell;
	}

	function renderAffiliationCell(index, data, column, isFirstColumn, doc) {
		const cell = createHtml(doc, "span", `cell ${column.className || ""} em-cell em-affil-cell`);
		const value = String(data || "").trim();
		if (!value) {
			return cell;
		}
		cell.setAttribute("title", value);
		const text = createHtml(doc, "span", "em-affil-text");
		text.textContent = value;
		cell.appendChild(text);
		return cell;
	}

	function renderLinksCell(index, data, column, isFirstColumn, doc) {
		const cell = createHtml(doc, "span", `cell ${column.className || ""} em-cell em-links-cell`);
		const links = ExtraMetaExtra.decodeLinks(data);
		for (const link of links) {
			const button = createHtml(doc, "button", `em-link-btn em-link-${link.kind}`);
			button.setAttribute("type", "button");
			button.setAttribute("title", link.tooltip);
			button.setAttribute("aria-label", link.tooltip);
			button.appendChild(createSvgIcon(doc, link.icon));
			attachExternalUrlAction(button, link.url);
			cell.appendChild(button);
		}
		return cell;
	}

	function renderArxivCell(index, data, column, isFirstColumn, doc) {
		const cell = createHtml(doc, "span", `cell ${column.className || ""} em-cell em-arxiv-cell`);
		const parsed = ExtraMetaExtra.parseArxiv(data);
		if (!parsed) {
			return cell;
		}
		if (!parsed.url) {
			const plain = createHtml(doc, "span", "em-arxiv-text");
			plain.textContent = parsed.id;
			plain.setAttribute("title", parsed.raw);
			cell.appendChild(plain);
			return cell;
		}
		const tooltip = parsed.category
			? `arXiv:${parsed.id} [${parsed.category}] — Open on arXiv`
			: `arXiv:${parsed.id} — Open on arXiv`;
		const button = createHtml(doc, "button", "em-arxiv-btn");
		button.setAttribute("type", "button");
		button.setAttribute("title", tooltip);
		button.setAttribute("aria-label", tooltip);
		const label = createHtml(doc, "span", "em-arxiv-label");
		label.textContent = parsed.id;
		button.appendChild(label);
		attachExternalUrlAction(button, parsed.url);
		cell.appendChild(button);
		return cell;
	}

	function registerColumns() {
		const specs = [
			{
				dataKey: "venue",
				label: "Venue",
				width: "96",
				minWidth: 64,
				dataProvider: (item) => ExtraMetaExtra.getValue(getExtraString(item), "tex.venueabbr"),
				renderCell: renderVenueCell,
			},
			{
				dataKey: "affiliation",
				label: "Affiliation",
				flex: 2,
				minWidth: 90,
				dataProvider: (item) => ExtraMetaExtra.getValue(getExtraString(item), "tex.affiliation"),
				renderCell: renderAffiliationCell,
			},
			{
				dataKey: "links",
				label: "Links",
				width: "90",
				minWidth: 54,
				dataProvider: (item) => ExtraMetaExtra.encodeLinks(getExtraString(item), getItemField(item, "url")),
				renderCell: renderLinksCell,
			},
			{
				dataKey: "arxiv",
				label: "arXiv",
				width: "98",
				minWidth: 74,
				dataProvider: (item) => ExtraMetaExtra.formatArxivData(getExtraString(item)),
				renderCell: renderArxivCell,
			},
		];

		for (const spec of specs) {
			try {
				const key = Zotero.ItemTreeManager.registerColumn({
					...spec,
					pluginID,
					enabledTreeIDs: ["main"],
					zoteroPersist: ["width", "hidden", "sortDirection"],
				});
				if (key) {
					registeredColumns.push(key);
				}
			}
			catch (e) {
				Zotero.logError(e);
			}
		}
	}

	function editedItems(item, tabType) {
		if (!item) {
			return [];
		}
		if (tabType && tabType !== "library") {
			return [item];
		}
		for (const win of Zotero.getMainWindows()) {
			for (const box of win.document.querySelectorAll("info-box")) {
				const extraItems = box.extraItems;
				if (box.item && box.item.id === item.id && Array.isArray(extraItems) && extraItems.length) {
					return [box.item, ...extraItems];
				}
			}
		}
		return [item];
	}

	function readFieldValue(item, field) {
		const extra = getExtraString(item);
		return field.getValue ? field.getValue(extra) : ExtraMetaExtra.getValue(extra, field.key);
	}

	function sharedFieldValue(items, field) {
		const eligible = items.filter(isEligibleItem);
		if (!eligible.length) {
			return "";
		}
		const first = readFieldValue(eligible[0], field);
		for (let i = 1; i < eligible.length; i++) {
			if (readFieldValue(eligible[i], field) !== first) {
				return "";
			}
		}
		return first;
	}

	async function writeFieldValue(items, key, value) {
		const eligible = items.filter(isEditableItem);
		if (!eligible.length) {
			return;
		}
		await Zotero.DB.executeTransaction(async () => {
			for (const item of eligible) {
				const current = item.getField("extra") || "";
				const updated = ExtraMetaExtra.setValue(current, key, value);
				if (updated !== current) {
					item.setField("extra", updated);
					await item.save();
				}
			}
		});
	}

	function registerInfoRows() {
		for (const field of INFO_FIELDS) {
			try {
				const rowID = Zotero.ItemPaneManager.registerInfoRow({
					rowID: `em-${field.id}`,
					pluginID,
					label: { l10nID: field.l10nID },
					position: "end",
					multiline: false,
					nowrap: false,
					editable: true,
					onGetData: ({ item, tabType }) => sharedFieldValue(editedItems(item, tabType), field),
					onSetData: ({ rowID: id, item, tabType, value }) => {
						const items = editedItems(item, tabType);
						const rawClean = ExtraMetaExtra.sanitizeValue(value);
						const clean = field.normalize ? field.normalize(rawClean) : rawClean;
						if (clean === null) {
							Zotero.ItemPaneManager.refreshInfoRow(id);
							return;
						}
						if (clean === sharedFieldValue(items, field)) {
							if (clean !== value) {
								Zotero.ItemPaneManager.refreshInfoRow(id);
							}
							return;
						}
						writeFieldValue(items, field.key, clean)
							.then(() => {
								if (clean !== value) {
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
				if (rowID) {
					registeredRows.push(rowID);
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

	function init(options) {
		pluginID = options.pluginID;
		registerColumns();
		registerInfoRows();
	}

	function shutdown() {
		for (const key of registeredColumns) {
			try {
				Zotero.ItemTreeManager.unregisterColumn(key);
			}
			catch (e) {
				Zotero.logError(e);
			}
		}
		for (const rowID of registeredRows) {
			try {
				Zotero.ItemPaneManager.unregisterInfoRow(rowID);
			}
			catch (e) {
				Zotero.logError(e);
			}
		}
		registeredColumns = [];
		registeredRows = [];
	}

	return { init, shutdown, addToWindow, removeFromWindow };
})();

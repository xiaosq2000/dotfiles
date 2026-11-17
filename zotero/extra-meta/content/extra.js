/*
 * Pure helpers for parsing and updating "Key: value" lines in Zotero's Extra field.
 * Zero Zotero dependencies so unit tests can import it directly under Node.
 */

var ExtraMetaExtra = (function () {
	"use strict";

	const LINE_PATTERN = /^([A-Za-z][A-Za-z0-9 ._-]*):([\s\S]*)$/;
	const ARXIV_MODERN_RE = /^(?:arXiv:\s*)?(\d{4}\.\d{4,5}(?:v\d+)?)(?:\s+\[([^\]]+)\])?/i;
	const ARXIV_LEGACY_RE = /^(?:arXiv:\s*)?([a-z-]+(?:\.[a-z-]+)?\/\d{7}(?:v\d+)?)(?:\s+\[([^\]]+)\])?/i;
	const ARXIV_URL_RE = /^(?:https?:\/\/)?arxiv\.org\/(?:abs|pdf|html)\/([^\s?#]+?)(?:\.pdf)?(?:[?#].*)?$/i;
	const OPENREVIEW_ID_RE = /^[A-Za-z0-9_-]{6,32}$/;

	function normalizeKey(key) {
		return String(key ?? "").trim().toLowerCase().replace(/[\s_-]+/g, "-");
	}

	function sanitizeValue(value) {
		return String(value ?? "").replace(/[\r\n]+/g, " ").trim();
	}

	function parseLine(line) {
		const match = LINE_PATTERN.exec(String(line ?? ""));
		if (!match) {
			return null;
		}
		const key = match[1].trim();
		return {
			key,
			normalizedKey: normalizeKey(key),
			value: sanitizeValue(match[2]),
		};
	}

	function getValue(extra, key) {
		if (!extra) {
			return "";
		}
		const target = normalizeKey(key);
		for (const line of String(extra).split("\n")) {
			const parsed = parseLine(line);
			if (parsed && parsed.normalizedKey === target && parsed.value !== "") {
				return parsed.value;
			}
		}
		return "";
	}

	/**
	 * Return Extra with `key` set to `value`. Existing line(s) for `key` are
	 * replaced at the first occurrence; an empty value removes the key.
	 */
	function setValue(extra, key, value) {
		const target = normalizeKey(key);
		const lines = extra ? String(extra).split("\n") : [];
		const kept = [];
		let insertAt = -1;

		for (const line of lines) {
			const parsed = parseLine(line);
			if (parsed && parsed.normalizedKey === target) {
				if (insertAt === -1) {
					insertAt = kept.length;
				}
				continue;
			}
			kept.push(line);
		}

		const clean = sanitizeValue(value);
		if (clean !== "") {
			if (insertAt === -1) {
				insertAt = kept.length;
				while (insertAt > 0 && kept[insertAt - 1] === "") {
					insertAt--;
				}
			}
			kept.splice(insertAt, 0, `${key}: ${clean}`);
		}
		return kept.join("\n");
	}

	/** Only allow http/https URLs to be launched externally. */
	function sanitizeUrl(raw) {
		const text = sanitizeValue(raw);
		if (!text) {
			return "";
		}
		try {
			const parsed = new URL(text);
			if (parsed.protocol === "http:" || parsed.protocol === "https:") {
				return parsed.href;
			}
		}
		catch {
			return "";
		}
		return "";
	}

	function isOpenReviewUrl(raw) {
		const url = sanitizeUrl(raw);
		if (!url) {
			return false;
		}
		try {
			const host = new URL(url).hostname.toLowerCase();
			return host === "openreview.net" || host.endsWith(".openreview.net");
		}
		catch {
			return false;
		}
	}

	function normalizeOpenReviewInput(raw) {
		const text = sanitizeValue(raw);
		if (!text) {
			return "";
		}
		if (OPENREVIEW_ID_RE.test(text)) {
			return `https://openreview.net/forum?id=${text}`;
		}
		const candidate = /^openreview\.net\//i.test(text) ? `https://${text}` : text;
		const url = sanitizeUrl(candidate);
		if (!url || !isOpenReviewUrl(url)) {
			return "";
		}
		try {
			const parsed = new URL(url);
			parsed.protocol = "https:";
			const forumId = parsed.searchParams.get("id");
			if ((parsed.pathname === "/pdf" || parsed.pathname === "/forum") && forumId) {
				const normalized = new URL("https://openreview.net/forum");
				normalized.searchParams.set("id", forumId);
				const noteId = parsed.searchParams.get("noteId");
				if (noteId) {
					normalized.searchParams.set("noteId", noteId);
				}
				return normalized.href;
			}
			return parsed.href;
		}
		catch {
			return "";
		}
	}

	function classifyLink(rawUrl, kind) {
		if (kind === "review") {
			const url = normalizeOpenReviewInput(rawUrl);
			if (!url) {
				return null;
			}
			return { kind: "review", label: "OpenReview", icon: "review", url, tooltip: `OpenReview: ${url}` };
		}

		const url = sanitizeUrl(rawUrl);
		if (!url) {
			return null;
		}
		let hostname = "";
		try {
			hostname = new URL(url).hostname.toLowerCase();
		}
		catch {
			hostname = "";
		}

		if (kind === "code") {
			let label = "Code";
			let icon = "code";
			if (hostname === "github.com" || hostname.endsWith(".github.com")) {
				label = "GitHub";
				icon = "github";
			}
			else if (hostname === "gitlab.com" || hostname.endsWith(".gitlab.com")) {
				label = "GitLab";
			}
			else if (hostname === "huggingface.co" || hostname.endsWith(".huggingface.co")) {
				label = "HF";
			}
			return { kind: "code", label, icon, url, tooltip: `Source Code: ${url}` };
		}

		return { kind: "page", label: "Site", icon: "globe", url, tooltip: `Project Page: ${url}` };
	}

	function getLinks(extra, itemUrl = "") {
		const codeLink = classifyLink(getValue(extra, "tex.sourcecode"), "code");
		const pageLink = classifyLink(getValue(extra, "tex.projecturl"), "page");
		const reviewSource = getValue(extra, "OpenReview")
			|| getValue(extra, "tex.openreview")
			|| (isOpenReviewUrl(itemUrl) ? itemUrl : "");
		const reviewLink = classifyLink(reviewSource, "review");
		const links = [];
		if (codeLink) {
			links.push(codeLink);
		}
		if (pageLink && (!codeLink || pageLink.url !== codeLink.url)) {
			links.push(pageLink);
		}
		if (reviewLink && !links.some((l) => l.url === reviewLink.url)) {
			links.push(reviewLink);
		}
		return links;
	}

	function encodeLinks(extra, itemUrl = "") {
		return getLinks(extra, itemUrl)
			.map((link) => `${link.kind}:${link.url}`)
			.join(" | ");
	}

	function decodeLinks(data) {
		if (!data) {
			return [];
		}
		const links = [];
		for (const part of String(data).split(" | ")) {
			const sep = part.indexOf(":");
			if (sep <= 0) {
				continue;
			}
			const kind = part.slice(0, sep);
			const url = part.slice(sep + 1);
			if (kind !== "code" && kind !== "page" && kind !== "review") {
				continue;
			}
			const classified = classifyLink(url, kind);
			if (classified) {
				links.push(classified);
			}
		}
		return links;
	}

	function parseArxiv(raw) {
		const text = sanitizeValue(raw);
		if (!text) {
			return null;
		}
		const urlMatch = ARXIV_URL_RE.exec(text);
		if (urlMatch) {
			const id = urlMatch[1];
			return { id, category: "", url: `https://arxiv.org/abs/${id}`, raw: text };
		}
		const modern = ARXIV_MODERN_RE.exec(text);
		if (modern) {
			return {
				id: modern[1],
				category: modern[2] ? modern[2].trim() : "",
				url: `https://arxiv.org/abs/${modern[1]}`,
				raw: text,
			};
		}
		const legacy = ARXIV_LEGACY_RE.exec(text);
		if (legacy) {
			return {
				id: legacy[1],
				category: legacy[2] ? legacy[2].trim() : "",
				url: `https://arxiv.org/abs/${legacy[1]}`,
				raw: text,
			};
		}
		return { id: text, category: "", url: "", raw: text };
	}

	function getArxiv(extra) {
		const direct = getValue(extra, "arXiv");
		if (direct) {
			return parseArxiv(direct);
		}
		const num = getValue(extra, "Number");
		if (/^arXiv:/i.test(num)) {
			return parseArxiv(num);
		}
		return null;
	}

	function formatArxivData(extra) {
		const parsed = getArxiv(extra);
		if (!parsed) {
			return "";
		}
		return parsed.category ? `${parsed.id} [${parsed.category}]` : parsed.id;
	}

	function normalizeArxivInput(raw) {
		const text = sanitizeValue(raw);
		if (!text) {
			return "";
		}
		const parsed = parseArxiv(text);
		if (!parsed) {
			return text;
		}
		return parsed.category ? `${parsed.id} [${parsed.category}]` : parsed.id;
	}

	return {
		normalizeKey,
		sanitizeValue,
		parseLine,
		getValue,
		setValue,
		sanitizeUrl,
		isOpenReviewUrl,
		normalizeOpenReviewInput,
		classifyLink,
		getLinks,
		encodeLinks,
		decodeLinks,
		parseArxiv,
		getArxiv,
		formatArxivData,
		normalizeArxivInput,
	};
})();

if (typeof module !== "undefined" && module.exports) {
	module.exports = ExtraMetaExtra;
}

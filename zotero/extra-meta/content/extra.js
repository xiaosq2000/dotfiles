/*
 * Pure helpers for parsing and updating "Key: value" lines in Zotero's Extra field.
 * Zero Zotero dependencies so unit tests can import it directly under Node.
 */

var ExtraMetaExtra = (function () {
	"use strict";

	const LINE_PATTERN = /^([A-Za-z][A-Za-z0-9 ._-]*):([\s\S]*)$/;
	const ARXIV_ID_CORE = "(?:\\d{4}\\.\\d{4,5}|[a-z-]+(?:\\.[a-z-]+)?\\/\\d{7})(?:v\\d+)?";
	const ARXIV_ID_RE = new RegExp(`^(?:arXiv:\\s*)?(${ARXIV_ID_CORE})(?:\\s+\\[([^\\]]+)\\])?$`, "i");
	const ARXIV_ID_EXACT_RE = new RegExp(`^${ARXIV_ID_CORE}$`, "i");
	const ARXIV_URL_RE = /^(?:https?:\/\/)?(?:export\.)?arxiv\.org\/(?:abs|pdf|html)\/([^\s?#]+?)(?:\.pdf)?\/?(?:[?#].*)?$/i;
	const OPENREVIEW_ID_RE = /^[A-Za-z0-9_-]{6,32}$/;

	function normalizeKey(key) {
		return String(key ?? "").trim().toLowerCase().replace(/[\s_-]+/g, "-");
	}

	function sanitizeValue(value) {
		return String(value ?? "").replace(/[\r\n]+/g, " ").trim();
	}

	function splitLines(extra) {
		return extra ? String(extra).split(/\r?\n/) : [];
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

	function parseFields(extra) {
		const fields = new Map();
		for (const line of splitLines(extra)) {
			const parsed = parseLine(line);
			if (parsed && parsed.value !== "" && !fields.has(parsed.normalizedKey)) {
				fields.set(parsed.normalizedKey, parsed.value);
			}
		}
		return fields;
	}

	function getValue(extra, key) {
		if (!extra) {
			return "";
		}
		return parseFields(extra).get(normalizeKey(key)) ?? "";
	}

	/**
	 * Return Extra with `key` set to `value`. Existing line(s) for `key` (and
	 * any alias lines matched by `isAliasLine`) are replaced at the first
	 * occurrence; an empty value removes them.
	 */
	function setValue(extra, key, value, isAliasLine = null) {
		const target = normalizeKey(key);
		const lines = splitLines(extra);
		const kept = [];
		let insertAt = -1;

		for (const line of lines) {
			const parsed = parseLine(line);
			if (parsed && (parsed.normalizedKey === target || (isAliasLine && isAliasLine(parsed)))) {
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
	function parseHttpUrl(raw) {
		const text = sanitizeValue(raw);
		if (!text) {
			return null;
		}
		try {
			const parsed = new URL(text);
			if (parsed.protocol === "http:" || parsed.protocol === "https:") {
				return parsed;
			}
		}
		catch {
			return null;
		}
		return null;
	}

	function sanitizeUrl(raw) {
		return parseHttpUrl(raw)?.href ?? "";
	}

	function isOpenReviewHost(hostname) {
		const host = hostname.toLowerCase();
		return host === "openreview.net" || host.endsWith(".openreview.net");
	}

	function isOpenReviewUrl(raw) {
		const parsed = parseHttpUrl(raw);
		return Boolean(parsed && isOpenReviewHost(parsed.hostname));
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
		const parsed = parseHttpUrl(candidate);
		if (!parsed || !isOpenReviewHost(parsed.hostname)) {
			return "";
		}
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

	function classifyLink(rawUrl, kind) {
		if (kind === "review") {
			const url = normalizeOpenReviewInput(rawUrl);
			if (!url) {
				return null;
			}
			return { kind: "review", label: "OpenReview", icon: "review", url, tooltip: `OpenReview: ${url}` };
		}

		const parsed = parseHttpUrl(rawUrl);
		if (!parsed) {
			return null;
		}
		const url = parsed.href;
		const hostname = parsed.hostname.toLowerCase();

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
		const fields = parseFields(extra);
		const codeLink = classifyLink(fields.get("tex.sourcecode") ?? "", "code");
		const pageLink = classifyLink(fields.get("tex.projecturl") ?? "", "page");
		const reviewSource = fields.get("openreview")
			|| fields.get("tex.openreview")
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
		const links = getLinks(extra, itemUrl);
		return links.length ? JSON.stringify(links) : "";
	}

	function decodeLinks(data) {
		if (!data) {
			return [];
		}
		try {
			const parsed = JSON.parse(String(data));
			if (!Array.isArray(parsed)) {
				return [];
			}
			return parsed.filter((link) => (
				link
				&& (link.kind === "code" || link.kind === "page" || link.kind === "review")
				&& typeof link.url === "string"
				&& typeof link.icon === "string"
				&& typeof link.tooltip === "string"
			));
		}
		catch {
			return [];
		}
	}

	function parseArxiv(raw) {
		const text = sanitizeValue(raw);
		if (!text) {
			return null;
		}
		const urlMatch = ARXIV_URL_RE.exec(text);
		if (urlMatch && ARXIV_ID_EXACT_RE.test(urlMatch[1])) {
			const id = urlMatch[1];
			return { id, category: "", url: `https://arxiv.org/abs/${id}`, raw: text };
		}
		const idMatch = ARXIV_ID_RE.exec(text);
		if (idMatch) {
			const id = idMatch[1];
			return {
				id,
				category: idMatch[2] ? idMatch[2].trim() : "",
				url: `https://arxiv.org/abs/${id}`,
				raw: text,
			};
		}
		return { id: text, category: "", url: "", raw: text };
	}

	function getArxiv(extra) {
		const fields = parseFields(extra);
		const direct = fields.get("arxiv");
		if (direct) {
			return parseArxiv(direct);
		}
		const num = fields.get("number") ?? "";
		if (/^arXiv:/i.test(num)) {
			return parseArxiv(num);
		}
		return null;
	}

	function formatParsedArxiv(parsed) {
		if (!parsed) {
			return "";
		}
		return parsed.category ? `${parsed.id} [${parsed.category}]` : parsed.id;
	}

	function formatArxivData(extra) {
		return formatParsedArxiv(getArxiv(extra));
	}

	function normalizeArxivInput(raw) {
		return formatParsedArxiv(parseArxiv(raw));
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

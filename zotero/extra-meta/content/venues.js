/*
 * Venue badge tone mapping. Uses Zotero 10's semantic theme variables in CSS
 * so badges adapt automatically to light mode, dark mode, and selected rows.
 */

var ExtraMetaVenues = (function () {
	"use strict";

	const VENUE_TONES = {
		// ML & Theory conferences
		NEURIPS: "purple",
		NIPS: "purple",
		ICML: "blue",
		ICLR: "cyan",
		AISTATS: "indigo",
		COLT: "indigo",
		AAAI: "indigo",
		IJCAI: "indigo",
		UAI: "indigo",
		// Robotics conferences
		CORL: "teal",
		RSS: "green",
		ICRA: "orange",
		IROS: "coral",
		HUMANOIDS: "orange",
		// Vision & Graphics
		CVPR: "plum",
		ICCV: "plum",
		ECCV: "plum",
		SIGGRAPH: "plum",
		// Journals & Transactions
		"RA-L": "gold",
		RAL: "gold",
		TRO: "gold",
		"T-RO": "gold",
		IJRR: "teal",
		IJRA: "teal",
		JMLR: "blue",
		TMLR: "cyan",
		TPAMI: "plum",
		NC: "green",
		NECO: "green",
		"ANN. MATH. STATIST.": "indigo",
		// Preprints
		ARXIV: "muted",
		BIORXIV: "muted",
		MEDRXIV: "muted",
		PREPRINT: "muted",
	};

	const FALLBACK_TONES = ["blue", "purple", "teal", "green", "orange", "plum"];

	function baseVenueKey(raw) {
		return String(raw ?? "")
			.trim()
			.replace(/\s+(?:19|20)\d{2}$/, "")
			.replace(/\s+/g, " ")
			.toUpperCase();
	}

	function resolveTone(raw) {
		const key = baseVenueKey(raw);
		if (!key) {
			return "muted";
		}
		if (Object.prototype.hasOwnProperty.call(VENUE_TONES, key)) {
			return VENUE_TONES[key];
		}
		// Match leading token like "NeurIPS Workshop" or "ICRA-W"
		const head = key.split(/[\s/-]/)[0];
		if (Object.prototype.hasOwnProperty.call(VENUE_TONES, head)) {
			return VENUE_TONES[head];
		}
		let hash = 0;
		for (let i = 0; i < key.length; i++) {
			hash = ((hash << 5) - hash + key.charCodeAt(i)) | 0;
		}
		return FALLBACK_TONES[Math.abs(hash) % FALLBACK_TONES.length];
	}

	return { baseVenueKey, resolveTone };
})();

if (typeof module !== "undefined" && module.exports) {
	module.exports = ExtraMetaVenues;
}

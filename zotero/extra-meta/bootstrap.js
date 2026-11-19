/*
 * Extra Meta: displays Extra metadata fields as styled columns and Info rows.
 */

/* global Zotero, Services */

var ExtraMetaExtra, ExtraMetaVenues, ExtraMetaMain;

var CONTENT_SCRIPTS = [
	"extra.js",
	"venues.js",
	"main.js",
];
var APP_SHUTDOWN_REASON = 2;
var chromeHandle = null;

function install() {}

async function startup({ id, version, rootURI }) {
	await Zotero.initializationPromise;

	const aomStartup = Components.classes["@mozilla.org/addons/addon-manager-startup;1"]
		.getService(Components.interfaces.amIAddonManagerStartup);
	chromeHandle = aomStartup.registerChrome(Services.io.newURI(rootURI + "manifest.json"), [
		["content", "extra-meta", "content/"],
	]);

	for (const file of CONTENT_SCRIPTS) {
		Services.scriptloader.loadSubScript(rootURI + "content/" + file);
	}

	ExtraMetaMain.init({ pluginID: id });
	for (const win of Zotero.getMainWindows()) {
		ExtraMetaMain.addToWindow(win);
	}
	Zotero.debug(`Extra Meta ${version}: started`);
}

function onMainWindowLoad({ window }) {
	if (ExtraMetaMain) {
		ExtraMetaMain.addToWindow(window);
	}
}

function onMainWindowUnload({ window }) {
	if (ExtraMetaMain) {
		ExtraMetaMain.removeFromWindow(window);
	}
}

function shutdown(data, reason) {
	if (reason === APP_SHUTDOWN_REASON) {
		return;
	}
	for (const win of Zotero.getMainWindows()) {
		ExtraMetaMain?.removeFromWindow(win);
	}
	ExtraMetaMain?.destroy?.();
	if (chromeHandle) {
		chromeHandle.destruct();
		chromeHandle = null;
	}
	ExtraMetaExtra = ExtraMetaVenues = ExtraMetaMain = undefined;
}

function uninstall() {}

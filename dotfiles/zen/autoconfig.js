// Zen on Linux: Cmd+, opens Settings, like the Mac. keyd makes the Cmd key
// (labeled Alt) send Ctrl, so this is Ctrl+, ("accel"). Firefox only has this
// key on macOS, and Zen's shortcut editor has no Settings entry to bind, so
// it's added here. An unsandboxed autoconfig file (installed in packages.nix),
// so it runs with chrome privileges, once per browser window. Its own keyset, since Zen rebuilds
// mainKeyset from its shortcuts file.
try {
  Services.obs.addObserver((win) => {
    const doc = win.document;
    if (doc.getElementById("key_cmdCommaSettings")) return;
    const keyset = doc.createXULElement("keyset");
    const key = doc.createXULElement("key");
    key.id = "key_cmdCommaSettings";
    key.setAttribute("key", ",");
    key.setAttribute("modifiers", "accel");
    key.addEventListener("command", () => win.openPreferences());
    keyset.appendChild(key);
    doc.documentElement.appendChild(keyset);
  }, "browser-delayed-startup-finished");
} catch (e) {
  Components.utils.reportError(e);
}

// Magnet-style tiling, like the Mac. Meh = Caps Lock held, which keyd sends as
// Ctrl+Super+Alt (see hosts/nixos). Each rect is [x, y, width, height] as
// fractions of the screen (minus the top bar).
import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {WINDOW_ANIMATION_TIME} from 'resource:///org/gnome/shell/ui/windowManager.js';
import * as Config from 'resource:///org/gnome/shell/misc/config.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

const MEH = '<Control><Super><Alt>';

// mutter 49 dropped the MaximizeFlags argument of unmaximize()
const MAXIMIZE_ARGS = parseInt(Config.PACKAGE_VERSION) >= 49 ? [] : [Meta.MaximizeFlags.BOTH];

// Padding (px) around tiled windows: GAP from the screen edges and GAP between
// two windows side by side. Same as Hyprland's (dotfiles/hypr/hyprland.lua).
const GAP = 24;

const BINDINGS = {
    [`${MEH}h`]: [0, 0, 1 / 2, 1], // left half
    [`${MEH}l`]: [1 / 2, 0, 1 / 2, 1], // right half
    [`<Shift>${MEH}h`]: [0, 0, 2 / 3, 1], // left two thirds
    [`<Shift>${MEH}l`]: [2 / 3, 0, 1 / 3, 1], // right third
    [`${MEH}space`]: [0, 0, 1, 1], // fill the screen, keeping the gaps
    [`<Shift>${MEH}space`]: [0.2, 0.2, 0.6, 0.6], // centered, 60%
};

// Meh+key opens the app, focuses it if it's already running, and hides
// (minimizes) all its windows if it's already focused.
// Values are .desktop file names (ls /run/current-system/sw/share/applications).
const APPS = {
    [`${MEH}g`]: 'github-desktop.desktop',
    [`${MEH}c`]: 'brave-browser.desktop',
    [`${MEH}x`]: 'dev.zed.Zed.desktop',
    [`${MEH}t`]: 'com.mitchellh.ghostty.desktop',
    [`${MEH}e`]: 'org.gnome.Geary.desktop',
    [`${MEH}n`]: 'md.obsidian.Obsidian.desktop',
    [`${MEH}a`]: 'com.anthropic.Claude.desktop',
    [`${MEH}r`]: 'org.gnome.Nautilus.desktop',
    [`${MEH}d`]: 'discord.desktop',
};

// Cmd+Q (keyd sends Ctrl+Q) force-kills the focused app, same as Hyprland
// (dotfiles/hypr/hyprland.lua). Apps in CLOSE_ONLY just get their window
// closed (Steam keeps running in the tray).
const KILL_APP = `${GLib.get_home_dir()}/.config/hypr/kill-app.sh`;
const CLOSE_ONLY = new Set(['steam']);

export default class TileExtension extends Extension {
    enable() {
        this._actions = new Map();
        this._clones = new Set();
        for (const [accel, rect] of Object.entries(BINDINGS))
            this._bind(accel, () => this._tile(rect));
        for (const [accel, id] of Object.entries(APPS))
            this._bind(accel, () => this._openApp(id));
        this._bind('<Control>q', () => this._quit());

        this._signal = global.display.connect('accelerator-activated', (_display, action) => {
            this._actions.get(action)?.();
        });
    }

    _bind(accel, callback) {
        const action = global.display.grab_accelerator(accel, Meta.KeyBindingFlags.NONE);
        if (action === Meta.KeyBindingAction.NONE) {
            console.warn(`tile@kody: ${accel} is already taken`);
            return;
        }
        Main.wm.allowKeybinding(Meta.external_binding_name_for_action(action), Shell.ActionMode.NORMAL);
        this._actions.set(action, callback);
    }

    _openApp(id) {
        const app = Shell.AppSystem.get_default().lookup_app(id);
        if (!app) {
            console.warn(`tile@kody: no app ${id}`);
            return;
        }
        // already focused: hide it, like Cmd+H on the Mac
        if (Shell.WindowTracker.get_default().focus_app === app) {
            for (const win of app.get_windows())
                win.minimize();
            return;
        }
        // focuses the most recent window if running, launches it otherwise
        app.activate();
    }

    _quit() {
        const win = global.display.focus_window;
        if (!win)
            return;
        if (CLOSE_ONLY.has((win.get_wm_class() ?? '').toLowerCase())) {
            win.delete(global.get_current_time());
            return;
        }
        const pid = win.get_pid();
        if (pid > 0)
            GLib.spawn_async(null, ['bash', KILL_APP, `${pid}`], null, GLib.SpawnFlags.SEARCH_PATH, null);
    }

    disable() {
        this._stopRetry();
        for (const clone of this._clones)
            clone.destroy();
        this._clones = null;
        global.display.disconnect(this._signal);
        for (const action of this._actions.keys()) {
            global.display.ungrab_accelerator(action);
            Main.wm.allowKeybinding(Meta.external_binding_name_for_action(action), Shell.ActionMode.NONE);
        }
        this._actions = null;
        this._signal = null;
    }

    _tile(rect) {
        const win = global.display.focus_window;
        if (!win || win.get_window_type() !== Meta.WindowType.NORMAL)
            return;

        this._stopRetry();
        const from = win.get_frame_rect();
        // Maximized, or snapped with Super+←/→ (which counts as maximized
        // vertically): undo that first, or mutter keeps the window pinned there.
        if (win.maximized_horizontally || win.maximized_vertically)
            win.unmaximize(...MAXIMIZE_ARGS);

        const area = win.get_work_area_current_monitor();
        const [x, y, w, h] = rect;
        const ax = area.x + GAP / 2, ay = area.y + GAP / 2;
        const aw = area.width - GAP, ah = area.height - GAP;
        const target = [
            Math.round(ax + x * aw + GAP / 2),
            Math.round(ay + y * ah + GAP / 2),
            Math.round(w * aw - GAP),
            Math.round(h * ah - GAP),
        ];
        this._animate(win, from, target);
        win.move_resize_frame(true, ...target);

        // Chromium/Electron apps (Brave, Claude) put back their own saved size
        // a moment after leaving maximized/snapped, undoing the move above.
        // Place them again until they stay put.
        let tries = 0;
        this._retry = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 60, () => {
            if (!win.get_compositor_private() || ++tries > 8) {
                this._retry = null;
                return GLib.SOURCE_REMOVE;
            }
            const f = win.get_frame_rect();
            if (f.x !== target[0] || f.y !== target[1] || f.width !== target[2] || f.height !== target[3])
                win.move_resize_frame(true, ...target);
            return GLib.SOURCE_CONTINUE;
        });
    }

    // GNOME's maximize animation, for any move: a snapshot of the window slides
    // and scales from where it was to `to` while fading out, and the window
    // fades in there underneath. Off when animations are off in Settings.
    _animate(win, from, to) {
        const actor = win.get_compositor_private();
        if (!actor || !St.Settings.get().enable_animations || from.width <= 0 || from.height <= 0)
            return;
        if (from.x === to[0] && from.y === to[1] && from.width === to[2] && from.height === to[3])
            return;

        let content;
        try {
            content = actor.paint_to_content(from);
        } catch {
            return;
        }
        const clone = new St.Widget({content, x: from.x, y: from.y, width: from.width, height: from.height});
        clone.set_offscreen_redirect(Clutter.OffscreenRedirect.ALWAYS);
        Main.uiGroup.add_child(clone);
        this._clones.add(clone);
        clone.ease({
            x: to[0],
            y: to[1],
            scale_x: to[2] / from.width,
            scale_y: to[3] / from.height,
            opacity: 0,
            duration: WINDOW_ANIMATION_TIME,
            mode: Clutter.AnimationMode.EASE_OUT_QUAD,
            onStopped: () => {
                this._clones?.delete(clone);
                clone.destroy();
            },
        });

        actor.opacity = 0;
        actor.ease({
            opacity: 255,
            duration: WINDOW_ANIMATION_TIME,
            mode: Clutter.AnimationMode.EASE_OUT_QUAD,
        });
    }

    _stopRetry() {
        if (this._retry) {
            GLib.source_remove(this._retry);
            this._retry = null;
        }
    }
}

# Builds Zed's Xcode theme from your nvim setup, so Zed colors code exactly
# like nvim. Run it after changing colors in nvim, then restart Zed:
#
#   python3 zed/xcode/build.py
#
# It asks nvim (dump.lua) for the colors it really uses, then writes:
#   themes/xcode.json  Xcode Dark + Xcode Light: the UI from the nvim Xcode
#                      palettes (nvim/lua/themes/xcode_*.lua), other languages'
#                      syntax colors from configs/code_syntax.lua's theme
#   themes/kodys.json  Kody's Theme Dark + Light: Xcode's UI and Swift colors,
#                      other languages in One Dark OLED's (themes/) or One
#                      Light's (xcode/one-light-syntax.json, from Zed's source),
#                      each also as a (Blur) variant over macOS's window blur;
#                      Dark's UI is One Dark - Darkened's instead
#                      (xcode/one-dark-darkened.json, the Zed extension's)
#   xcode/groups.json  for sourcekit.lua: each nvim Swift highlight group's
#                      color (as a token type) and bold / strikethrough
#   settings.json      semantic_token_rules: those token types -> the theme

import json, re, subprocess, tempfile
from pathlib import Path

here = Path(__file__).resolve().parent
zed = here.parent
nvim_themes = zed.parent / "nvim" / "lua" / "themes"

# the palette names that color Swift code (xcode_theme.lua)
SYNTAX_COLORS = ["text", "comment", "keyword", "string", "number", "preprocessor",
                 "attribute", "url", "type_declaration", "other_declaration", "type",
                 "member", "project_type", "project_member"]


def colors(lua_file):
    """The color table of an nvim theme: top-level keys, plus `ui = { ... }`."""
    src = re.sub(r"--[^\n]*", "", lua_file.read_text())
    pairs = lambda s: dict(re.findall(r'(\w+)\s*=\s*"(#[0-9a-fA-F]{6})"', s))
    blocks = dict(re.findall(r"(\w+)\s*=\s*(\{[^{}]*\})", src))
    top = re.sub(r"\w+\s*=\s*\{[^{}]*\}", "", src)
    c = pairs(top)
    c["ui"] = pairs(blocks.get("ui", ""))
    c.setdefault("folder", "#5ab3f4")
    return c


def mix(a, b, pct):
    s = pct / 100
    ca = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    cb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x * (1 - s) + y * s):02x}" for x, y in zip(ca, cb))


def zed_style(st):
    """An nvim style (dump.lua) as a Zed theme syntax style."""
    d = {"color": st["fg"]} if st.get("fg") else {}
    if st.get("bold"):
        d["font_weight"] = 700
    if st.get("italic"):
        d["font_style"] = "italic"
    return d


def theme(name, kind, c, syntax):
    shade = lambda p: mix(c["bg"], c["text"], p)
    u = dict(darker_black=shade(6), black2=shade(12), one_bg=shade(13),
             one_bg2=shade(17), one_bg3=shade(20), grey=shade(25),
             grey_fg=shade(33), grey_fg2=shade(40), light_grey=shade(48),
             line=shade(15), statusline_bg=shade(7), lightbg=shade(14))
    u.update(c["ui"])
    sep = c.get("separator") or shade(20)
    warning = c.get("warning") or c["number"]
    t, bg = c["text"], c["bg"]
    # a system-blue cursor, like Xcode / macOS (nvim: scope_braces.lua)
    cursor = "#007aff"
    # scope_braces.lua's gold brackets, as a see-through block behind the
    # bracket pair at the cursor (Zed keeps the brackets' own text color)
    gold = "#b8860b59" if kind == "light" else "#ffd60a73"
    chrome = u["darker_black"]
    # Zed's own see-through amounts for an expanded diff hunk: fill, hollow
    # background, hollow border
    hunk = (0.16, 0.08, 0.48) if kind == "light" else (0.12, 0.06, 0.36)

    a = lambda hex_, alpha: hex_ + alpha
    see_through = lambda hex_, o: hex_ + f"{round(o * 255):02x}"
    style = {
        "background": chrome, "surface.background": chrome,
        "elevated_surface.background": u["statusline_bg"],
        "panel.background": chrome, "status_bar.background": chrome,
        "title_bar.background": chrome, "title_bar.inactive_background": chrome,
        "toolbar.background": bg, "tab_bar.background": chrome,
        "tab.inactive_background": chrome, "tab.active_background": bg,
        "border": sep, "border.variant": u["line"], "border.focused": c["selection"],
        "border.selected": c["selection"], "border.transparent": "#00000000",
        "border.disabled": u["one_bg2"], "pane_group.border": sep,
        "element.background": u["one_bg"], "element.hover": u["one_bg2"],
        "element.active": u["one_bg3"], "element.selected": u["one_bg3"],
        "element.disabled": u["one_bg"],
        "ghost_element.background": "#00000000", "ghost_element.hover": u["one_bg"],
        "ghost_element.active": u["one_bg2"], "ghost_element.selected": u["one_bg2"],
        "ghost_element.disabled": u["one_bg"],
        "drop_target.background": a(c["selection"], "80"),
        "text": t, "text.muted": u["light_grey"], "text.placeholder": u["grey_fg2"],
        "text.disabled": u["grey_fg"], "text.accent": c["url"],
        "icon": t, "icon.muted": u["light_grey"], "icon.disabled": u["grey_fg"],
        "icon.placeholder": u["grey_fg2"], "icon.accent": c["folder"],
        "search.match_background": a(warning, "40"),
        "scrollbar.thumb.background": a(u["grey_fg"], "66"),
        "scrollbar.thumb.hover_background": u["grey_fg"],
        "scrollbar.thumb.border": "#00000000",
        "scrollbar.track.background": "#00000000", "scrollbar.track.border": "#00000000",
        "editor.foreground": t, "editor.background": bg,
        "editor.gutter.background": bg, "editor.subheader.background": chrome,
        "editor.active_line.background": c["current_line"],
        "editor.highlighted_line.background": c["current_line"],
        "editor.line_number": c.get("line_number") or u["grey"],
        "editor.active_line_number": t, "editor.invisible": u["grey"],
        "editor.wrap_guide": shade(9), "editor.active_wrap_guide": shade(18),
        "editor.indent_guide": shade(9), "editor.indent_guide_active": shade(18),
        "editor.document_highlight.read_background": a(c["selection"], "99"),
        "editor.document_highlight.write_background": a(c["selection"], "cc"),
        "editor.document_highlight.bracket_background": gold,
        "terminal.background": bg, "terminal.foreground": t,
        "terminal.bright_foreground": t, "terminal.dim_foreground": c["comment"],
        "terminal.ansi.black": u["one_bg3"], "terminal.ansi.bright_black": u["light_grey"],
        "terminal.ansi.red": c["string"], "terminal.ansi.bright_red": c["string"],
        "terminal.ansi.green": c["project_member"], "terminal.ansi.bright_green": c["project_type"],
        "terminal.ansi.yellow": warning, "terminal.ansi.bright_yellow": warning,
        "terminal.ansi.blue": c["url"], "terminal.ansi.bright_blue": c["type_declaration"],
        "terminal.ansi.magenta": c["keyword"], "terminal.ansi.bright_magenta": c["type"],
        "terminal.ansi.cyan": c["other_declaration"], "terminal.ansi.bright_cyan": c["type_declaration"],
        "terminal.ansi.white": t, "terminal.ansi.bright_white": t,
        "link_text.hover": c["url"],
        "error": c["string"], "error.background": a(c["string"], "1a"), "error.border": a(c["string"], "66"),
        "warning": warning, "warning.background": a(warning, "1a"), "warning.border": a(warning, "66"),
        "info": c["url"], "info.background": a(c["url"], "1a"), "info.border": a(c["url"], "66"),
        "hint": c["comment"], "hint.background": a(c["comment"], "1a"), "hint.border": a(c["comment"], "66"),
        "success": c["project_member"], "success.background": a(c["project_member"], "1a"),
        "success.border": a(c["project_member"], "66"),
        "created": c["project_member"], "modified": warning, "deleted": c["string"],
        "conflict": c["preprocessor"], "ignored": u["grey_fg"], "hidden": u["grey_fg"],
        "predictive": u["grey_fg2"], "unreachable": c["comment"],
        # git: changed lines in the gutter and scrollbar, and files' git status,
        # in the cursor's blue, like Xcode's change bar. Expanded diffs keep
        # green / red (Zed would tint them from these), else removed and added
        # lines look the same
        "version_control.added": cursor, "version_control.modified": cursor,
        "version_control.deleted": cursor,
        **{f"editor.diff_hunk.{status}.{part}": see_through(color, o)
           for status, color in (("added", c["project_member"]), ("deleted", c["string"]))
           for part, o in zip(("background", "hollow_background", "hollow_border"), hunk)},
        "players": [{"cursor": cursor, "background": cursor, "selection": c["selection"]}],
        "syntax": syntax,
    }
    style.update(terminal[kind])
    return {"name": name, "appearance": kind, "style": style}


palettes = {"dark": colors(nvim_themes / "xcode_dark.lua"),
            "light": colors(nvim_themes / "xcode_light.lua")}

# the terminal in Ghostty's colors: the themes ghostty/config picks for dark /
# light (files in ghostty/themes/). The background stays the theme's
ANSI = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]


def ghostty_terminal():
    ghostty = zed.parent / "ghostty"
    conf = (ghostty / "config").read_text()
    picked = dict(re.findall(r"(dark|light):\s*([^,\n]+)",
                             re.search(r"^theme\s*=\s*(.+)$", conf, re.M)[1]))
    out = {}
    for kind, file in picked.items():
        path = ghostty / "themes" / file.strip()
        if not path.exists():
            raise SystemExit(f"ghostty theme {file.strip()!r}: not a file in ghostty/themes")
        # "foreground = e0def4", "palette = 1=#e06c75" -> g["foreground"], g["palette 1"]
        g = {}
        for k, i, v in re.findall(r"^([\w-]+)\s*=\s*(?:(\d+)\s*=\s*)?#?([0-9a-fA-F]{6})\s*$",
                                  path.read_text(), re.M):
            g[f"{k} {i}" if i else k] = "#" + v.lower()
        t = {"terminal.foreground": g["foreground"], "terminal.bright_foreground": g["foreground"]}
        for i, color in enumerate(ANSI):
            t[f"terminal.ansi.{color}"] = g[f"palette {i}"]
            t[f"terminal.ansi.bright_{color}"] = g[f"palette {i + 8}"]
        out[kind] = t
    return out


terminal = ghostty_terminal()

with tempfile.TemporaryDirectory() as tmp:
    out = Path(tmp) / "dump.json"
    subprocess.run(["nvim", "--headless", f"+luafile {here / 'dump.lua'}", str(out)],
                   check=True, stdin=subprocess.DEVNULL)
    dump = json.loads(out.read_text())

# Swift: one Zed style per color nvim uses (named after its palette entry,
# xc_keyword...), so a token's type is its color
names = {mode: {p[n].lower(): n for n in reversed(SYNTAX_COLORS)} for mode, p in palettes.items()}
keys = {}  # (dark fg, light fg) -> style name


def color_key(dark, light):
    pair = (dark, light)
    if pair not in keys:
        name = names["dark"].get(dark)
        if not name or names["light"].get(light) != name:
            name = f"color{len(keys)}"  # not a palette color
        keys[pair] = "xc_" + name
    return keys[pair]


text_type = color_key(palettes["dark"]["text"].lower(), palettes["light"]["text"].lower())
groups = {}
for group, modes in sorted(dump["swift"].items()):
    dark, light = modes["dark"] or {}, modes["light"] or {}
    if not dark and not light:
        continue  # nvim draws nothing for it
    if bool(dark.get("fg")) != bool(light.get("fg")):
        raise SystemExit(f"{group}: colored in only one of light / dark")
    st = {}
    if dark.get("fg"):
        st["fg"] = color_key(dark["fg"], light["fg"])
    if dark.get("bold") or light.get("bold"):
        st["bold"] = True
    if dark.get("strikethrough") or light.get("strikethrough"):
        st["strike"] = True
    if st:
        groups[group] = st

types = sorted(set(keys.values()))
(here / "groups.json").write_text(json.dumps({
    "parser": dump["parser"],
    "query_files": dump["query_files"],
    "sourcekit_legend": dump["sourcekit_legend"],
    "types": types,
    "modifiers": ["bold", "strike"],
    "text_type": text_type,
    "groups": groups,
}, indent=1, sort_keys=True) + "\n")


def syntax(mode):
    s = {}
    for name, modes in sorted(dump["code"].items()):
        if modes[mode] and zed_style(modes[mode]):
            s[name] = zed_style(modes[mode])
    for (dark, light), key in keys.items():
        s[key] = {"color": dark if mode == "dark" else light}
    return s


(zed / "themes" / "xcode.json").write_text(json.dumps({
    "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
    "name": "Xcode",
    "author": "Kody Deda",
    "themes": [theme("Xcode Dark", "dark", palettes["dark"], syntax("dark")),
               theme("Xcode Light", "light", palettes["light"], syntax("light"))],
}, indent=2) + "\n")


def one_syntax(mode):
    """Xcode's Swift colors, other languages in One Dark OLED / One Light's."""
    if mode == "dark":
        oled = json.loads((zed / "themes" / "one-dark-oled.json").read_text())
        s = dict(oled["themes"][0]["style"]["syntax"])
    else:
        s = dict(json.loads((here / "one-light-syntax.json").read_text())["syntax"])
    for (dark, light), key in keys.items():
        s[key] = {"color": dark if mode == "dark" else light}
    return s


# the (Blur) variants: the window's color this solid (hex alpha), over macOS's
# blur of what's behind; the lower, the more a white window behind washes the
# dark theme out to gray. The title and status bars sit on the blur itself, so they get
# it too; the file tree, tab bar and editor are drawn over the window's
# background, so the tree and unfocused tabs are see-through (else near
# solid) and the editor only a tint. Popovers and menus stay solid.
# The editor's tint is near solid, so code sits on its own color and only the
# bars, file tree and tab bar show the blur; dark's editor is Dark OLED's:
# solid, with its current line
BLUR_ALPHA = {"dark": "e0", "light": "e6"}
TINT_ALPHA = {"dark": "f2", "light": "f2"}
# light's window color: white, as what shows through (a dark desktop) only
# darkens it; at e6 that's a light gray tinted by the desktop, like Xcode's
# sidebar. Its own #f3f2f2 came out too dark, and more opaque hides the blur.
# dark's: near black instead of its own gray, with the dividers darkened to
# match (picked by hand: no one formula gives all three)
WINDOW = {"light": "#ffffff", "dark": "#040405"}
BLUR_BORDERS = {"dark": {"border": "#1c1c21", "border.variant": "#151518",
                         "border.disabled": "#18181c", "pane_group.border": "#1c1c21"}}
OVER_BACKGROUND = ["panel.background", "tab_bar.background", "tab.inactive_background"]
BLURRED = ["background", "surface.background", "panel.background",
           "status_bar.background", "title_bar.background",
           "title_bar.inactive_background", "toolbar.background",
           "tab_bar.background", "tab.inactive_background", "tab.active_background",
           "editor.background", "editor.gutter.background",
           "editor.subheader.background", "editor.active_line.background",
           "editor.highlighted_line.background", "terminal.background"]
SOLID_EDITOR = ["editor.background", "editor.gutter.background", "toolbar.background",
                "tab.active_background"]


def blurred(t):
    style = dict(t["style"], **{"background.appearance": "blurred"})
    window = style["background"]
    blur, tint = BLUR_ALPHA[t["appearance"]], TINT_ALPHA[t["appearance"]]
    recolor = WINDOW.get(t["appearance"], window)
    for k in BLURRED:
        if k in OVER_BACKGROUND:
            style[k] = recolor + "00"
        elif style[k] == window:
            style[k] = recolor + blur
        elif len(style[k]) == 7:
            style[k] += tint
    if t["appearance"] == "dark":
        style.update({k: t["style"][k] for k in SOLID_EDITOR})
        style["editor.active_line.background"] = style["editor.highlighted_line.background"] = OLED_LINE
    # the file tree's sticky folders: rows scroll under them, so they need a
    # fill, the window's (left unset, Zed's default is a solid darker band)
    style["panel.overlay_background"] = recolor + blur
    style["panel.overlay_hover"] = style["element.hover"]
    style.update(BLUR_BORDERS.get(t["appearance"], {}))
    return {**t, "name": t["name"] + " (Blur)", "style": style}


# Kody's Theme Dark itself: all of One Dark - Darkened's UI (bars, panels,
# tabs, borders, text, the editor's surfaces, the terminal's background). What
# isn't UI stays: the code's colors, the cursor and selection, git's blue,
# diffs, the gold brackets, and the colors for errors, warnings, git status.
# Ours it doesn't set (indent guides, pane dividers) go back to Zed's default.
OWN = ("syntax", "players", "editor.foreground", "editor.diff_hunk.",
       "editor.document_highlight.", "search.match_background", "version_control.",
       "terminal.ansi.", "terminal.foreground", "terminal.bright_foreground",
       "terminal.dim_foreground", "error", "warning", "info", "hint", "success",
       "created", "modified", "deleted", "renamed", "conflict", "ignored", "hidden",
       "predictive", "unreachable")


def one_dark_darkened(t):
    ui = json.loads((here / "one-dark-darkened.json").read_text())["themes"][0]["style"]
    style = {k: v for k, v in t["style"].items() if k in ui or k.startswith(OWN)}
    style.update({k: v for k, v in ui.items() if not k.startswith(OWN)})
    return {**t, "style": style}


# Dark OLED: the dark theme with what the (Blur) variant blurs (the window
# color: title and status bars, file tree, tab bar) solid black instead. The
# editor and terminal keep their own near-black, the current line just a
# shade lighter (the dark theme's is too bright on it). The dividers go darker
# by as much as the window did, so they stand out from black as little as
# they did from the window's gray.
OLED_LINE = "#1a1b1f"
OLED_DARKER = ["border", "border.variant", "border.disabled", "pane_group.border"]


def oled(t):
    s = t["style"]
    window = s["background"]
    rgb = lambda c: [int(c[i:i + 2], 16) for i in (1, 3, 5)]
    oled = {k: "#000000" for k in BLURRED + ["panel.overlay_background"]
            if k in OVER_BACKGROUND or s.get(k) == window}
    oled["editor.active_line.background"] = oled["editor.highlighted_line.background"] = OLED_LINE
    for k in OLED_DARKER:
        oled[k] = "#" + "".join(f"{max(a - b, 0):02x}" for a, b in zip(rgb(s[k]), rgb(window)))
    return {**t, "name": t["name"] + " OLED", "style": dict(s, **oled)}


# Kody's Theme Light: the secondary text (muted, gitignored, hidden, disabled)
# this far (%) from the background to the text, as the dark theme's amounts
# are too faint on white to read in the file tree
LIGHT_TEXT = {"text.muted": 72, "icon.muted": 72, "text.placeholder": 62,
              "icon.placeholder": 62, "text.disabled": 55, "icon.disabled": 55,
              "ignored": 55, "hidden": 55}


def readable_light(t):
    c = palettes["light"]
    return {**t, "style": dict(t["style"], **{k: mix(c["bg"], c["text"], p) for k, p in LIGHT_TEXT.items()})}


dark = theme("Kody's Theme Dark", "dark", palettes["dark"], one_syntax("dark"))
light = readable_light(theme("Kody's Theme Light", "light", palettes["light"], one_syntax("light")))
(zed / "themes" / "kodys.json").write_text(json.dumps({
    "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
    "name": "Kody's Theme",
    "author": "Kody Deda",
    "themes": [one_dark_darkened(dark), light, blurred(dark), blurred(light), oled(dark)],
}, indent=2) + "\n")

# semantic_token_rules: each type in its color, with each combination of
# bold / strike (first match wins, so both first)
rules = []
for t in types:
    rules += [
        {"token_type": t, "token_modifiers": ["bold", "strike"], "style": [t], "font_weight": "bold", "strikethrough": True},
        {"token_type": t, "token_modifiers": ["strike"], "style": [t], "strikethrough": True},
        {"token_type": t, "token_modifiers": ["bold"], "style": [t], "font_weight": "bold"},
        {"token_type": t, "style": [t]},
    ]
settings = zed / "settings.json"
text = settings.read_text()
block = ",\n".join("      " + json.dumps(r) for r in rules)
text, n = re.subn(r'("semantic_token_rules": \[).*?(\n    \])', lambda m: m[1] + "\n" + block + m[2], text, flags=re.S)
if n != 1:
    raise SystemExit("settings.json: no semantic_token_rules block to fill")

# theme_overrides: those types in every other theme too, Xcode's light or dark
# colors to match the theme, so Swift looks like Xcode whatever the theme
BUILT_IN = {"One Dark": "dark", "One Light": "light", "Ayu Dark": "dark",
            "Ayu Light": "light", "Ayu Mirage": "dark", "Gruvbox Dark": "dark",
            "Gruvbox Dark Hard": "dark", "Gruvbox Dark Soft": "dark",
            "Gruvbox Light": "light", "Gruvbox Light Hard": "light",
            "Gruvbox Light Soft": "light"}
installed = dict(BUILT_IN)
extensions = Path.home() / "Library" / "Application Support" / "Zed" / "extensions" / "installed"
for f in sorted([*extensions.glob("*/themes/*.json"), *(zed / "themes").glob("*.json")]):
    for t in json.loads(f.read_text()).get("themes", []):
        installed[t["name"]] = t.get("appearance", "dark")
overrides = {name: {**terminal[kind],
                    "syntax": {key: {"color": dark if kind == "dark" else light}
                               for (dark, light), key in sorted(keys.items(), key=lambda kv: kv[1])}}
             for name, kind in sorted(installed.items()) if not name.startswith(("Xcode ", "Kody's Theme "))}
block = ",\n".join(f"    {json.dumps(name)}: {json.dumps(o)}" for name, o in overrides.items())
text, n = re.subn(r'("theme_overrides": \{).*?(\n  \})', lambda m: m[1] + "\n" + block + m[2], text, flags=re.S)
if n != 1:
    raise SystemExit("settings.json: no theme_overrides block to fill")
settings.write_text(text)
print(f"{len(groups)} Swift groups in {len(types)} colors, in {len(installed)} themes; themes/xcode.json, xcode/groups.json, settings.json written")

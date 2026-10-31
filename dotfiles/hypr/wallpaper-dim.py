#!/usr/bin/env python3
# wallpaper-dim.py: darkens the wallpaper, and only the wallpaper, for zen
# mode 2 (Meh+7, hyprland.lua). Hyprland's own dimming (dim_around) darkens
# everything behind a window, other apps included; this instead lays a
# see-through black sheet over each monitor on the layer just above the
# wallpaper (layer shell's "bottom"), so every window stays on top of it,
# undimmed. Clicks go straight through it. It fades in and out with
# Hyprland's layer animation.
#
#   wallpaper-dim.py <strength>   start (0 to 1, e.g. 0.9); does nothing if
#                                 it's already running
#   wallpaper-dim.py off          stop
#
# A tiny Wayland client written straight against the protocol, so it needs
# nothing but Python (no GTK).
import array
import os
import signal
import socket
import struct
import sys

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
PIDFILE = os.path.join(RUNTIME, "wallpaper-dim.pid")


# the pid of the one that's running, if any
def running():
    try:
        with open(PIDFILE) as f:
            pid = int(f.read())
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            if pid != os.getpid() and b"wallpaper-dim" in f.read():
                return pid
    except (OSError, ValueError):
        pass
    return None


if len(sys.argv) != 2:
    sys.exit(__doc__ or "usage: wallpaper-dim.py <strength> | off")
if sys.argv[1] == "off":
    pid = running()
    if pid:
        os.kill(pid, signal.SIGTERM)
    sys.exit(0)
if running():
    sys.exit(0)
ALPHA = round(min(max(float(sys.argv[1]), 0.0), 1.0) * 255)

with open(PIDFILE, "w") as f:
    f.write(str(os.getpid()))


def stop(*_):
    try:
        with open(PIDFILE) as f:
            if int(f.read()) == os.getpid():
                os.remove(PIDFILE)
    except (OSError, ValueError):
        pass
    sys.exit(0)  # closing the connection takes the sheets away


signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)

# ── the Wayland wire protocol ───────────────────────────────────────────────


def uints(*values):
    return struct.pack(f"<{len(values)}I", *values)


def ints(*values):
    return struct.pack(f"<{len(values)}i", *values)


def string(text):
    data = text.encode() + b"\0"
    return struct.pack("<I", len(data)) + data + b"\0" * (-len(data) % 4)


def read_string(payload, offset):
    (n,) = struct.unpack_from("<I", payload, offset)
    text = payload[offset + 4 : offset + 4 + n - 1].decode()
    return text, offset + 4 + n + (-n % 4)


display = os.environ.get("WAYLAND_DISPLAY", "wayland-0")
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect(display if display.startswith("/") else os.path.join(RUNTIME, display))

handlers = {}  # object id -> function(opcode, payload)
next_id = 2  # 1 is wl_display


def new_id(handler=None):
    global next_id
    oid, next_id = next_id, next_id + 1
    if handler:
        handlers[oid] = handler
    return oid


def send(oid, opcode, args=b"", fds=()):
    msg = struct.pack("<II", oid, (8 + len(args)) << 16 | opcode) + args
    ancillary = [(socket.SOL_SOCKET, socket.SCM_RIGHTS, array.array("i", fds))] if fds else []
    sock.sendmsg([msg], ancillary)


pending = b""


def dispatch():
    global pending
    data = sock.recv(65536)
    if not data:
        stop()  # Hyprland went away
    pending += data
    while len(pending) >= 8:
        oid, word = struct.unpack_from("<II", pending)
        size = word >> 16
        if len(pending) < size:
            break
        payload, pending = pending[8:size], pending[size:]
        handler = handlers.get(oid)
        if handler:
            handler(word & 0xFFFF, payload)


def display_event(opcode, payload):
    if opcode == 0:  # error
        _, code = struct.unpack_from("<II", payload)
        message, _ = read_string(payload, 8)
        sys.exit(f"wallpaper-dim: Wayland error {code}: {message}")


handlers[1] = display_event


def roundtrip():
    done = []
    callback = new_id(lambda opcode, payload: done.append(True))
    send(1, 0, uints(callback))  # wl_display.sync
    while not done:
        dispatch()


# ── globals ─────────────────────────────────────────────────────────────────

globals_ = {}  # interface -> [(name, version)]
ready = False


def registry_event(opcode, payload):
    if opcode != 0:  # global_remove: the sheet on a removed monitor gets closed
        return
    (name,) = struct.unpack_from("<I", payload)
    interface, offset = read_string(payload, 4)
    (version,) = struct.unpack_from("<I", payload, offset)
    globals_.setdefault(interface, []).append((name, version))
    if interface == "wl_output" and ready:
        cover(name)  # a monitor plugged in


registry = new_id(registry_event)
send(1, 1, uints(registry))  # wl_display.get_registry
roundtrip()


def bind(interface, max_version, name=None):
    if interface not in globals_:
        sys.exit(f"wallpaper-dim: the compositor has no {interface}")
    gname, version = next((g for g in globals_[interface] if name in (None, g[0])))
    oid = new_id()
    send(registry, 0, uints(gname) + string(interface) + uints(min(version, max_version), oid))
    return oid


compositor = bind("wl_compositor", 4)
shm = bind("wl_shm", 1)
layer_shell = bind("zwlr_layer_shell_v1", 4)
viewporter = bind("wp_viewporter", 1)

# one black pixel at the strength's opacity (ARGB8888, premultiplied: stored
# B, G, R, A), stretched over each monitor
fd = os.memfd_create("wallpaper-dim")
os.write(fd, bytes((0, 0, 0, ALPHA)))
pool = new_id()
send(shm, 0, uints(pool) + ints(4), fds=[fd])  # wl_shm.create_pool
os.close(fd)

# ── a sheet per monitor ─────────────────────────────────────────────────────

LAYER_BOTTOM = 1
ANCHOR_ALL = 1 | 2 | 4 | 8  # top, bottom, left, right


def cover(output_name):
    output = bind("wl_output", 3, output_name)
    buffer = new_id()
    send(pool, 0, uints(buffer) + ints(0, 1, 1, 4) + uints(0))  # create_buffer
    surface = new_id()
    send(compositor, 0, uints(surface))  # create_surface
    region = new_id()
    send(compositor, 1, uints(region))  # create_region (empty)
    send(surface, 5, uints(region))  # set_input_region: clicks go through
    send(region, 0)  # destroy
    viewport = new_id()
    send(viewporter, 1, uints(viewport, surface))  # get_viewport

    def layer_event(opcode, payload):
        if opcode == 0:  # configure
            serial, width, height = struct.unpack_from("<III", payload)
            send(layer, 6, uints(serial))  # ack_configure
            if width and height:
                send(viewport, 2, ints(width, height))  # set_destination
                send(surface, 1, uints(buffer) + ints(0, 0))  # attach
                send(surface, 2, ints(0, 0, width, height))  # damage
            send(surface, 6)  # commit
        elif opcode == 1:  # closed: its monitor went away
            send(layer, 7)  # destroy
            send(surface, 0)

    layer = new_id(layer_event)
    # get_layer_surface on the bottom layer: above the wallpaper, under windows
    send(layer_shell, 0, uints(layer, surface, output, LAYER_BOTTOM) + string("wallpaper-dim"))
    send(layer, 1, uints(ANCHOR_ALL))  # set_anchor: the whole monitor
    send(layer, 2, ints(-1))  # set_exclusive_zone: the bar's strip too
    send(surface, 6)  # commit: Hyprland answers with a configure


for name, _ in globals_.get("wl_output", []):
    cover(name)
ready = True

while True:
    dispatch()

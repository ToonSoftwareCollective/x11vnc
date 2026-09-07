# x11vnc with built-in multitouch injection for the Toon 1 and 2

Clicks and drags from a VNC client are written as Linux multitouch (MT protocol B) events straight into the
touchscreen event device, so the Toon's qt-gui reacts to them like real finger touches.



## What the patch does for Toon 2

Stock x11vnc's `touch` mode writes `ABS_X`, `ABS_Y`, `ABS_PRESSURE`,
`SYN_REPORT`. Qt's evdevtouch plugin opens the SSD254x touchscreen as a
multitouch device and only looks at `ABS_MT_*` events, so those single-touch
events are ignored. The patch adds a UINPUT option `mt` that makes
`ptr_abs()` emit exactly the sequence plus an explicit `ABS_MT_SLOT`:

```
press / drag:  ABS_MT_SLOT 0, ABS_MT_TRACKING_ID 1 (first report only),
               ABS_MT_POSITION_X, ABS_MT_POSITION_Y, ABS_MT_TOUCH_MAJOR 5,
               BTN_TOUCH 1 (first report only), ABS_X, ABS_Y, ABS_PRESSURE,
               SYN_REPORT
release:       ABS_MT_SLOT 0, ABS_MT_TRACKING_ID -1, BTN_TOUCH 0,
               ABS_MT_TOUCH_MAJOR 0, ABS_PRESSURE 0, SYN_REPORT
```

New UINPUT options (all optional except `mt`):

| Option | Default | Meaning |
|--------|---------|---------|
| `mt` | off | enable multitouch injection, implies `touch` and `abs` |
| `mt_id=N` | 1 | `ABS_MT_TRACKING_ID` used for the injected finger |
| `mt_major=N` | 5 | `ABS_MT_TOUCH_MAJOR` value while down |
| `mt_slot=N` | 0 | `ABS_MT_SLOT` to address, `-1` sends no slot event |

The patch also fixes the timestamp handling so the file compiles with
64-bit `time_t` C libraries (musl), and `shutdown_uinput()` releases a
finger that is still down when x11vnc exits. `x11vnc -help` documents the
option under `-pipeinput UINPUT`.

### Missing screen updates: fix for Toon 1 and Toon 2

Qt eglfs on the i.MX6 GPU renders into two or three buffers inside
`/dev/fb0` and pans the display between them (the framebuffer's virtual
height is a multiple of 600). Stock x11vnc with `map:/dev/fb0@1024x600x32`
only ever reads the first 1024x600 pixels, so whenever the display shows
buffer 1 or 2 the VNC picture is stale while the Toon reacts to touches
normally. The patch makes the `map:` rawfb code detect a Linux framebuffer
device, map the whole video memory, and re-read the pan offset with
`FBIOGET_VSCREENINFO` before every polling pass, so the VNC client always
sees the buffer that is on the LCD. The log shows what was detected:

## Installation on the Toon 1 and 2

```sh
mkdir -p /usr/local/lib/toon2-x11vnc-mt
copy x11vnc and start-toon2-mt-vnc.sh into that directory (scp/sftp)
chmod +x /usr/local/lib/toon2-x11vnc-mt/*

usage:

/usr/local/lib/toon2-x11vnc-mt/start-toon2-mt-vnc.sh start
/usr/local/lib/toon2-x11vnc-mt/start-toon2-mt-vnc.sh stop
```

The x11vnc log goes to `/tmp/x11vnc.log`.

Authentication is controlled by `AUTH_OPTS` at the top of the script. It is
empty by default (no VNC password). Set it to `-usepw` to use the existing
`~/.vnc/passwd` like the old setup did. Do not comment out lines inside the
backslash-continued x11vnc command; that silently drops the options after it.


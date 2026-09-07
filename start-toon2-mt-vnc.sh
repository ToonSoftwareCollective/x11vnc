#!/bin/sh
#
# filename    : start-toon2-mt-vnc.sh
# parameter 1 : start | stop
# purpose     : run the multitouch-aware x11vnc on a Toon 2
#
# The x11vnc binary next to this script is a static build of x11vnc 0.9.13
# with the new "mt" UINPUT option (see x11vnc-0.9.13-multitouch.patch).
# It writes Linux multitouch protocol B events straight into the touchscreen
# event device, which is what qt-gui's evdevtouch plugin listens to.
#
if [ "$1" != "start" ] && [ "$1" != "stop" ]; then
  echo "."
  echo ". Usage: $0 start|stop"
  echo "."
  exit 0
fi

SCRIPTDIR=$(dirname "$(readlink -f "$0")")
X11VNC=$SCRIPTDIR/x11vnc
TOUCH_DEVICE=${TOUCH_DEVICE:-/dev/input/touchscreen0}
LOGFILE=/tmp/x11vnc.log
#
# VNC authentication. Empty = no password (anyone on the LAN can connect).
# Set to "-usepw" to use ~/.vnc/passwd like the old setup did.
#
AUTH_OPTS=""

if [ ! -x "$X11VNC" ]; then
  echo "x11vnc executable not found or not executable: $X11VNC" >&2
  exit 1
fi

echo "."
echo ". Make sure x11vnc is down"
killall -9 x11vnc >/dev/null 2>&1 || true

if [ "$1" = "start" ]; then
  if [ ! -e "$TOUCH_DEVICE" ]; then
    echo "touchscreen device not found: $TOUCH_DEVICE" >&2
    exit 1
  fi
  echo "."
  echo ". Start x11vnc (log: $LOGFILE)"
  echo "."
  #
  # UINPUT options:
  #   mt              inject one finger as multitouch protocol B (implies touch,abs)
  #   mt_id=N         tracking id to use              (default 1)
  #   mt_major=N      ABS_MT_TOUCH_MAJOR value        (default 5)
  #   mt_slot=N       ABS_MT_SLOT to use, -1 = none   (default 0)
  #   pressure=N      ABS_PRESSURE value while down
  #   direct_abs=DEV  write the events into DEV instead of a uinput device
  #   nouinput        do not create a uinput device at all
  #
  # Set X11VNC_UINPUT_DEBUG=1 in the environment to log every injected event.

  "$X11VNC" -forever -shared \
    -rawfb map:/dev/fb0@1024x600x32 \
    $AUTH_OPTS \
    -pipeinput "UINPUT:mt,touch_always=1,pressure=128,direct_abs=$TOUCH_DEVICE,nouinput" \
    -o "$LOGFILE" -bg
  echo "."
fi

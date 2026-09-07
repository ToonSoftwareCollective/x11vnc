#!/bin/sh
#
# filename    : start-toon1-vnc.sh
# parameter 1 : start | stop
# purpose     : run the patched static x11vnc on a Toon 1 (qb2, ARMv5)
#
# Same x11vnc source as the Toon 2 build (multitouch "mt" option + fbdev
# pan following), compiled for the Toon 1 CPU.  The Toon 1 has a resistive
# single-touch screen, so the classic x11vnc "touch" injection with the
# tslib calibration file is used here, as in the original 2016 qb2 package.
#
if [ "$1" != "start" ] && [ "$1" != "stop" ]; then
  echo "."
  echo ". Usage: $0 start|stop"
  echo "."
  exit 0
fi

SCRIPTDIR=$(dirname "$(readlink -f "$0")")
X11VNC=$SCRIPTDIR/x11vnc
TOUCH_DEVICE=${TOUCH_DEVICE:-/dev/input/event0}
TSLIB_CAL=${TSLIB_CAL:-/etc/pointercal}
FB_GEOMETRY=${FB_GEOMETRY:-800x480x32}
LOGFILE=/tmp/x11vnc.log
#
# VNC authentication. Empty = no password (anyone on the LAN can connect).
# Set to "-usepw" to use ~/.vnc/passwd.  (This build has no SSL support,
# so the old "-ssl SAVE -vencrypt ..." options are not available.)
#
AUTH_OPTS=""

if [ ! -x "$X11VNC" ]; then
  echo "x11vnc executable not found or not executable: $X11VNC" >&2
  exit 1
fi

echo "."
echo ". Make sure x11vnc is down"
killall -9 x11vnc >/dev/null 2>&1 || true
killall -9 x11vnc-bin >/dev/null 2>&1 || true

if [ "$1" = "start" ]; then
  if [ ! -e "$TOUCH_DEVICE" ]; then
    echo "touchscreen device not found: $TOUCH_DEVICE" >&2
    exit 1
  fi
  TSLIB_OPT=""
  if [ -f "$TSLIB_CAL" ]; then
    TSLIB_OPT=",tslib_cal=$TSLIB_CAL"
  else
    echo "note: no tslib calibration file $TSLIB_CAL, injecting raw coordinates"
  fi
  echo "."
  echo ". Start x11vnc (log: $LOGFILE)"
  echo "."
  # If the Toon 1 GUI turns out to need multitouch events as well, replace
  # "touch,abs" below by "mt" (see the README in the parent folder).
  # Set X11VNC_UINPUT_DEBUG=1 in the environment to log every injected event.
  "$X11VNC" -forever -shared \
    -rawfb "map:/dev/fb0@$FB_GEOMETRY" \
    $AUTH_OPTS \
    -pipeinput "UINPUT:touch,touch_always=1,abs,pressure=128${TSLIB_OPT},direct_abs=$TOUCH_DEVICE,direct_btn=$TOUCH_DEVICE,direct_rel=$TOUCH_DEVICE,direct_key=$TOUCH_DEVICE,nouinput" \
    -cursor arrow \
    -o "$LOGFILE" -bg
  echo "."
fi

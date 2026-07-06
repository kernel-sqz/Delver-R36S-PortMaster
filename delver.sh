#!/bin/bash
# PORTMASTER: delver.zip, Delver.sh

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

FORCE_BUNDLED_JRE=1
FORCE_GPTOKEYB=0

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source "$controlfolder/control.txt"
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"

get_controls

GAMEDIR="/$directory/ports/delver"

> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

echo "=== DELVER START ==="
date

export HOME="$GAMEDIR"
export XDG_CONFIG_HOME="$GAMEDIR/config"
export XDG_DATA_HOME="$GAMEDIR/data"
export XDG_CACHE_HOME="$GAMEDIR/cache"

mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$GAMEDIR/tmp"

cd "$GAMEDIR" || exit 1

########################################
# First run: extract Steam assets
########################################

if [ ! -d "$GAMEDIR/audio" ] || [ ! -d "$GAMEDIR/generator" ] || [ ! -f "$GAMEDIR/meshes.png" ]; then
  echo "Game assets not found."

  if [ ! -f "$GAMEDIR/delver.jar" ]; then
    pm_message "Delver assets missing.\n\nCopy the Steam Linux delver.jar into:\n\n$GAMEDIR\n\nThen launch Delver again."
    exit 1
  fi

  echo "Validating delver.jar..."

  if ! command -v unzip >/dev/null 2>&1; then
    pm_message "unzip is missing on this system.\n\nPlease install or update PortMaster/runtime tools."
    exit 1
  fi

  if ! unzip -l "$GAMEDIR/delver.jar" | grep -q "audio/whoosh1.mp3"; then
    pm_message "Invalid delver.jar.\n\nPlease copy delver.jar from the Steam Linux version of Delver."
    exit 1
  fi

  if ! unzip -l "$GAMEDIR/delver.jar" | grep -q "meshes.png"; then
    pm_message "Invalid delver.jar.\n\nRequired Delver assets were not found."
    exit 1
  fi

  echo "Extracting Steam assets from delver.jar..."
  unzip -o "$GAMEDIR/delver.jar" -d "$GAMEDIR"

  if [ $? -ne 0 ]; then
    pm_message "Failed to extract delver.jar."
    exit 1
  fi

  # The Steam UI skin is for the older LWJGL2 build and is incompatible with this port's LWJGL3 engine.
  # The port uses the UI bundled inside game.jar instead.
  rm -rf "$GAMEDIR/ui"

  rm -f "$GAMEDIR/delver.jar"
  rm -rf "$GAMEDIR/META-INF" "$GAMEDIR/com" "$GAMEDIR/org" "$GAMEDIR/net" "$GAMEDIR/javazoom"
  rm -f "$GAMEDIR"/*.dll "$GAMEDIR"/*.so "$GAMEDIR"/*.dylib "$GAMEDIR"/*.jnilib

  sync

  echo "Asset extraction complete."
fi

# Migration cleanup for installs that already extracted the Steam UI before this script version.
if [ -f "$GAMEDIR/ui/skin.json" ]; then
  echo "Removing incompatible Steam UI assets..."
  rm -rf "$GAMEDIR/ui"
fi


if [ ! -f "$GAMEDIR/game.jar" ]; then
  pm_message "game.jar is missing.\n\nPlease reinstall the Delver PortMaster port."
  exit 1
fi

########################################
# Java runtime
########################################

# Set to 1 to always use the bundled JRE, even if the system provides Java.


JAVA_BIN=""

if [ "$FORCE_BUNDLED_JRE" = "1" ]; then
  if [ -x "$GAMEDIR/jre/bin/java" ]; then
    JAVA_BIN="$GAMEDIR/jre/bin/java"
  elif [ -x "$GAMEDIR/jre-linux/linux64/bin/java" ]; then
    JAVA_BIN="$GAMEDIR/jre-linux/linux64/bin/java"
  elif [ -x "$GAMEDIR/java/bin/java" ]; then
    JAVA_BIN="$GAMEDIR/java/bin/java"
  fi
else
  if command -v java >/dev/null 2>&1; then
    JAVA_BIN="$(command -v java)"
  elif [ -x "$GAMEDIR/jre/bin/java" ]; then
    JAVA_BIN="$GAMEDIR/jre/bin/java"
  elif [ -x "$GAMEDIR/jre-linux/linux64/bin/java" ]; then
    JAVA_BIN="$GAMEDIR/jre-linux/linux64/bin/java"
  elif [ -x "$GAMEDIR/java/bin/java" ]; then
    JAVA_BIN="$GAMEDIR/java/bin/java"
  fi
fi

if [ -z "$JAVA_BIN" ]; then
  pm_message "Java Runtime not found.\n\nThis port requires Java.\n\nPlease add a Linux aarch64 JRE to one of these locations:\n\n$GAMEDIR/jre/\n$GAMEDIR/jre-linux/linux64/\n$GAMEDIR/java/"
  exit 1
fi

JAVA_HOME_DIR="$(dirname "$(dirname "$JAVA_BIN")")"
export JAVA_HOME="$JAVA_HOME_DIR"
export PATH="$(dirname "$JAVA_BIN"):$PATH"

echo "Using Java: $JAVA_BIN"
"$JAVA_BIN" -version

########################################
# Weston runtime
########################################

weston_dir=/tmp/weston
$ESUDO mkdir -p "${weston_dir}"

weston_runtime="weston_pkg_0.2"

if [ ! -f "$controlfolder/libs/${weston_runtime}.squashfs" ]; then
  if [ ! -f "$controlfolder/harbourmaster" ]; then
    pm_message "This port requires the latest PortMaster runtime files."
    sleep 5
    exit 1
  fi

  $ESUDO "$controlfolder/harbourmaster" --quiet --no-check runtime_check "${weston_runtime}.squashfs"
fi

if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "${weston_dir}" 2>/dev/null
fi

echo "Mounting Weston runtime..."
$ESUDO mount "$controlfolder/libs/${weston_runtime}.squashfs" "${weston_dir}"

echo "Starting Delver..."

pm_platform_helper "$GAMEDIR/game.jar" >/dev/null

########################################
# Input helper
########################################

GPTOKEYB_PID=""
GPTK_FILE="$GAMEDIR/delver.gptk"

# Set to 1 to force gptokeyb on every CFW.
# Leave at 0 to enable it only on muOS.

# muOS may expose the built-in controls in a way that Java/LWJGL does not read directly.
# dArkOS-RE and other CFWs that already work without this helper are left untouched.
if { [ "$FORCE_GPTOKEYB" = "1" ] || [ "$CFW_NAME" = "muOS" ]; } && [ -f "$GPTK_FILE" ]; then
  echo "Starting gptokeyb2 for muOS input mapping..."
  $GPTOKEYB2 "java" -c "$GPTK_FILE" &
  GPTOKEYB_PID=$!
fi

$ESUDO env \
XDG_DATA_HOME="$XDG_DATA_HOME" \
XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
XDG_CACHE_HOME="$XDG_CACHE_HOME" \
HOME="$HOME" \
JAVA_HOME="$JAVA_HOME" \
PATH="$PATH" \
$weston_dir/westonwrap.sh \
headless noop kiosk crusty_glx_gl4es \
"$JAVA_BIN" -jar "$GAMEDIR/game.jar"

RET=$?

echo "Game exited with code $RET"

if [ -n "$GPTOKEYB_PID" ]; then
  echo "Stopping gptokeyb2..."
  kill "$GPTOKEYB_PID" 2>/dev/null
fi

if [ "$FORCE_GPTOKEYB" = "1" ] || [ "$CFW_NAME" = "muOS" ]; then
  $ESUDO pkill -9 -f gptokeyb 2>/dev/null
  $ESUDO pkill -9 -f gptokeyb2 2>/dev/null
fi

echo "Cleaning Weston..."
$ESUDO $weston_dir/westonwrap.sh cleanup

if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "${weston_dir}" 2>/dev/null
fi

pm_finish

exit $RET
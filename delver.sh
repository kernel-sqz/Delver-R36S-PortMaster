#!/bin/bash
# PORTMASTER: delver.zip, Delver.sh

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

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

GAMEDIR="/roms/ports/delver"

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

$ESUDO env \
XDG_DATA_HOME="$XDG_DATA_HOME" \
HOME="$HOME" \
JAVA_HOME="$JAVA_HOME" \
$weston_dir/westonwrap.sh \
headless noop kiosk crusty_glx_gl4es \
java -jar "$GAMEDIR/game.jar"

RET=$?

echo "Game exited with code $RET"

echo "Cleaning Weston..."
$ESUDO $weston_dir/westonwrap.sh cleanup

if [[ "$PM_CAN_MOUNT" != "N" ]]; then
  $ESUDO umount "${weston_dir}" 2>/dev/null
fi

pm_finish

exit $RET
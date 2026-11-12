#!/usr/bin/env bash
# Bring Roblox Studio to the front (KDE Plasma on Wayland, via KWin
# scripting), so Studio MCP screen captures aren't black. Run it right
# before each capture. On X11, `xdotool search --name "Roblox Studio"
# windowactivate` does the same.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript focusstudio >/dev/null 2>&1 || true
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$here/focus-studio.js" focusstudio >/dev/null
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null
sleep 0.5
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript focusstudio >/dev/null

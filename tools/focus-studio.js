// KWin script: bring the Roblox Studio window to the front so Studio keeps
// rendering (it stops drawing the viewport while inactive, and Studio MCP
// screen captures then come back black). Run via tools/focus-studio.sh.
const wins = workspace.windowList ? workspace.windowList() : workspace.clientList();
for (const w of wins) {
  if (w.caption && w.caption.indexOf("Roblox Studio") !== -1) {
    if (w.minimized) w.minimized = false;
    workspace.activeWindow = w;
    break;
  }
}

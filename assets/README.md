# assets/ → ReplicatedStorage.Assets

Rojo syncs this folder into `ReplicatedStorage/Assets`. Models saved here as
`.rbxm` override the placeholder art the code builds, without touching any
script. If a file is missing, the game falls back to the built-in look, so
the game always runs.

| File | What it replaces | Used by |
|---|---|---|
| `Grass/GrassTuft.rbxm` | The grass blades drawn on every lawn cell (fallback: green wedges) | `GrassVisuals.client.luau` |
| `Tools/<ToolId>.rbxm` | The model of one tool/mower, e.g. `Tools/push_mower.rbxm` (fallback: built from Parts in `Shared/ToolModels.luau`) | `ToolVisualService` |

## Adding the Low Poly Grass (Asset Picker choice, Creator Store 14566481901)

1. In Studio, open the Toolbox (View → Toolbox), search **Low Poly Grass**
   or open https://create.roblox.com/store/asset/14566481901 and click
   **Get**, then insert it from *My Models* / Inventory.
2. Audit it (docs/ASSETS.md): delete every `Script`, `LocalScript` and
   `ModuleScript` inside it.
3. Make it a single `Model` named **GrassTuft**. Any size is fine, the game
   scales it to fit one grass cell. Leave it upright (+Y is up).
4. Right-click it in Explorer → **Save to File…** → save as
   `assets/Grass/GrassTuft.rbxm` in this repo. Delete the copy from
   Workspace.
5. Rojo picks it up; press Play.

Tool models work the same way: a `Model` named after the tool id
(`push_mower`, `riding_mower`…), facing −Z (Roblox "front"), saved as
`assets/Tools/<ToolId>.rbxm`. Audit scripts first, always.

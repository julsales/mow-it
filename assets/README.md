# assets/ → ReplicatedStorage.Assets

Rojo syncs this folder into `ReplicatedStorage/Assets`. Models saved here as
`.rbxm` override the placeholder art the code builds, without touching any
script. If a file is missing, the game falls back to the built-in look, so
the game always runs.

| File | What it replaces | Used by |
|---|---|---|
| `ServerStorage/ToolOverrides/<ToolId>` (in the place file, not in git) | Same as below, for models Rojo can't sync (Unions, MeshParts). Current: `nail_clipper` = Creator Store 10276788826. Save the place after changing it | `ToolModels` (server) |
| (none: `art/tools/`) | The low-poly Blender art for all 48 tools, loaded by `ToolArtService` from the asset ids in `Shared/Config/ToolArt.luau` (art/tools/README.md). Takes priority over `ToolOverrides` | `ToolModels` |
| `Tools/<ToolId>.rbxm` | The model of one tool/mower, e.g. `Tools/push_mower.rbxm` (fallback: built from Parts in `Shared/ToolModels.luau`) | `ToolVisualService` |

## Adding a mesh asset (how the Low Poly Grass was added, Creator Store 14566481901)

Rojo cannot sync a `MeshPart`'s mesh (it arrives empty). For a single-mesh
asset, read its MeshId and size in Studio and write a `.model.json` with a
`Part` + `SpecialMesh` (FileMesh) instead, like `Grass/GrassTuft.model.json`.
For multi-part models, saving to `.rbxm` below works.

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

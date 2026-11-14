# Hay yard art (Blender → Roblox)

The baler, a hay bale, the stacking pallet and the silo (with its bale
elevator and sales counter), made by Python scripts with the same kit and
style as the tools (`art/tools/lib.py`, see `art/tools/README.md`).

| File | What it is |
|---|---|
| `yard_models.py` | The four models. Front is +Z. Moving pieces are built inside `rig("Name")` / `sub("Name")` blocks. |
| `build.py` | Checks that nothing floats or sinks, exports `out/<model>.fbx` and `out/meta.json` (authored boxes, rig pivots), renders four views per model with a stand-in player to `out/views/`. |
| `sync_config.py` | Writes ids (`out/assets.json`) and boxes/pivots into `Shared/Config/HayYard.luau` (Models). |

```bash
flatpak run org.blender.Blender -b --factory-startup --python $PWD/art/yard/build.py
python3 art/yard/sync_config.py
```

The build must end with `AUDIT total: 0 problem(s)`.

Upload like the tools (group-owned Model assets through Studio MCP
`open_cloud_invoke`, files copied to `~/Documents/MowItYardArt/`), record
the ids in `out/assets.json`, run `sync_config.py`.

How the game uses them: `ToolArtService` loads them into
`ReplicatedStorage/YardArt`; `Map/HayYard` builds the yard from painted
copies (`Shared/YardArt`); mesh names are colour groups
(`Config/HayYard.Paint`, falling back to the tools' shared pieces); pieces
named `Group#Rig` are animated by `HayRigs` as described by
`Config/HayYard.Pieces.<piece>.Rigs`. Points the game needs (where a bale
comes out, where the belt starts) are `Markers` in the same config, in
the coordinates used here.

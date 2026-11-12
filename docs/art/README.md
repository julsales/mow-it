# Interface artwork

The current editable document is [mow-it-ui.fig](openpencil/mow-it-ui.fig).
It contains two design boards plus five reusable components, created in the
owner's open OpenPencil document through its authenticated local RPC server.
The document was saved as a new named file, preserving `Untitled.fig`.
OpenPencil confirmed Montserrat ExtraBold was faithfully available.

- [HUD and passes preview](openpencil/hud-passes.png)
- [Quest discovery states and rewards direction](openpencil/quests-rewards.png)
- `tools/build-ui-design.py` produces editable SVG import sources.
- `tools/render-ui-chrome.py` rasterizes the editor's exported component SVGs,
  removing only its erroneous opaque root background to preserve transparency.

The design preview uses illustrative zero balances. Live labels stay native
Roblox text. The passes menu uses unpublished offers marked **Coming soon**;
checkout stays disabled until server entitlements are implemented and tested.
The five new chrome images await upload and Play verification; the 14 icon
images below already have IDs. Neither a preview nor a successful Rojo build
establishes that this revision fits the live Studio viewport.

`ui-reference.png` is the owner's supplied direction, not a game screenshot.
`asset-brief.md` records the intended individual assets and generation prompts.

The active HUD uses **14 original project-authored icons**, with editable SVG
masters in `assets/UI/source/` and transparent 1024×1024 PNGs in `assets/UI/`.
They are deterministic vector drawings, not AI bitmap generations or enlarged
reference crops. `tools/build-ui-icons.py` renders them with CairoSVG; its
preview includes 112, 48 and 24px versions in `icons-v2-preview.png`.
The family follows the owner's outlined farm style and includes clear, rain,
golden sun, moon night and storm. Current uploaded IDs are centralized in
`Shared/Config/Interface.luau`. The older reference crops and study sheets are
historical direction only and are no longer bound to the HUD.

Canva generated the following studies on 2026-11-12. They are useful style/sprite
boards, but did not follow the request for one isolated icon per output:

- [Full-interface study 1](https://www.canva.com/M/MAHaq5ogsiQ)
- [Full-interface study 2](https://www.canva.com/M/MAHaq-pSsPM)
- [Shop component sheet](https://www.canva.com/M/MAHaq3iGhBA)
- [Chest component sheet](https://www.canva.com/M/MAHaq1wCIvc)

The connector supplied 200px previews and Canva links, not full-resolution
exports. These previews are kept in `studies/`; the original studies remain in
Canva. Browser export requires a Canva login; automatic background removal also
requires a paid Canva plan, so neither was assumed or purchased.

## Superseded source-reference icons (historical IDs)

Uploaded through Studio MCP to this experience. IDs are centralized in
`Shared/Config/Interface.luau`:

| File | Roblox image id |
| --- | --- |
| shop-stall.png | 127830764053370 |
| starter-chest.png | 134837235908062 |
| crew-paw.png | 111251629969216 |
| quests-sheet.png | 74916140279573 |
| rewards-gift.png | 92295205321531 |
| clover.png | 83187049352088 |
| coin.png | 86799307172150 |
| grass-sprout.png | 139707865889082 |

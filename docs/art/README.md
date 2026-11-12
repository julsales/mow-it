# Interface artwork

## Current generated-art revision

The current visual direction is the owner's simulator reference,
`references/simulator-ui-owner.png`, with the passes grid following the newer
`references/passes-grid-owner.png` (three upper cards and two wider lower cards).
The flat brown-outline OpenPencil board
below was rejected as too simple and is retained only as history.

The **native image_gen** tool generated 20 separate runtime-art candidates in
`assets/UI/generated-v3/`, plus a concept and presentation-only background.
The source PNGs preserve the generator's alpha. `generated-v3/prompts.json`
records the exact prompts and generation filenames. No separate API key or
CLI fallback was used.

The owner selected the rounded-ray sun, with a reflective gold variant, a red
quest exclamation and a single-coin currency icon. The coin stack remains an
offer illustration. Long banners are separate from icons, labels and effects.

OpenPencil assembly: [mow-it-ui-v3.fig](generated-v3/mow-it-ui-v3.fig).
The page **Mow It - Generated UI v3** contains five active boards:

1. [HUD and passes](generated-v3/board-1.png)
2. [Full shop scroll content](generated-v3/board-2.png)
3. [Daily rewards](generated-v3/board-3.png)
4. [Quest discovery / offer / progress](generated-v3/board-4.png)
5. [Generated asset library](generated-v3/board-5.png)

Illustrations and skin images are independent image-filled layers; text and
basic UI geometry remain editable native nodes. Replaced assembly drafts are
preserved on **Mow It - Assembly archive**, keeping the active page free of
stale lint findings without overwriting the owner's original page/file. Previews are
design mockups with sample progress/balances, not Studio captures or a working
OpenPencil scroll prototype. The long board specifies the scroll contents;
Roblox must use a clipped viewport and dynamic ScrollingFrame canvas.

`tools/assemble-generated-ui.py` builds the layered boards in bounded batches
against an already-open authenticated local OpenPencil server. It reads the
local token internally without logging or committing it. `assembly.json` and
`openpencil-nodes.json` record layout and node mapping; temporary progress lives
in `/tmp/mowit-pencil-assembly-v3.json`. Commands: `prepare`, `import --board N`,
`fill --board N --limit 8`, `export --board N`, `lint`, `save`; `rebuild` preserves the
previous owned board on the archive page when available. All five exported boards were visually inspected. Native frame surfaces
carry explicit fills and corner radii. The native editor contrast check for
the active boards is recorded in `generated-v3/contrast-audit.json`. The
whole active page is also clean for the color-contrast rule, as recorded in
`generated-v3/contrast-page-audit.json` (zero errors or warnings for both).

Roblox upload, runtime skin binding, responsive input/scroll behavior and Play
verification remain pending. Current runtime image IDs still reference the
previous icon family; the new generated assets have not been uploaded.

## Previous vector revision (superseded visual direction)

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

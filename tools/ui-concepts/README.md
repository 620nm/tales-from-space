# UI concept gallery

A local, interactive comparison of three proposed gameplay layouts. It uses
the pack's baked sprites in an illustrative scene. It does not connect to a
game server, load the pack runtime, or demonstrate production sandbox support.
The current gameplay UI continues to live in `ui/`.

## Export and capture

Requires Node 22+ with native WebSocket support, the engine's existing baked
`web/assets/atlas.ron`, `delivery.ron`, and atlas objects. Capture additionally
requires a local Chromium executable. No dependencies are installed.

```sh
node tools/ui-concepts/build.mjs \
  --engine /home/josh/Source/lunatic \
  --output /tmp/tfs-concepts.html
node tools/ui-concepts/capture.mjs \
  --input /tmp/tfs-concepts.html --output /tmp/tfs-concept-shots
```

Open the exported HTML directly in a browser. All scripts, styles and sprites
are embedded; no web server or network access is needed. The exporter and
capture command refuse to overwrite existing output files. Use another output
name for a revised export. `capture.mjs --browser /path/to/chrome` selects a
browser explicitly. Screenshots are working artifacts outside the repository.
`--width 1366 --height 768` changes the capture size; the desktop studies target
1366×768 and larger screens, rather than a phone layout.

The comparison controls change layout, open a sample device, and show design
notes. Inventory containers, hands, and chat support local mock interactions.
These do not execute gameplay actions. Slot art comes from the existing atlas;
the frames and layout are original HTML/CSS. No additional tg assets are baked.

## The alternatives

| Concept | Arrangement | Main tradeoff |
| --- | --- | --- |
| Classic side rail | Playfield left, chat and information right; equipment lower-left, hands centered, targeting lower-right | Reserves horizontal room; the clearest default for chat-heavy play |
| Bottom console | World above an opaque deck containing chat, inventory and targeting | Fits wide displays; less vertical chat history and world height |
| Compact overlay | Large world with a short chat feed and a stable lower HUD; history expands on request | More world area; transient interfaces still cover it |

The 4:3 playfield in the classic concept is a proposed presentation preset.
tg does not require it: the reference declares 15×15 and 19×15 logical views
(`tgstation/code/__DEFINES/hud.dm:18-23`); the skin's initial 640×480 map
pane resizes (`tgstation/interface/skin.dmf:58-79`).

Across layouts, the proposed inventory contract is one open container,
compact rows growing upward, a highlighted source slot, and hands that never
move when the tray opens. Source-linked placement is a refinement of tg's
fixed lower-screen tray, not a claim about tg's exact placement.
tg's default is seven columns (`tgstation/code/datums/storage/storage.dm:107-121`),
one active container (`:1080-1103`), and capacity-dependent rows (`:1151-1178`).
Hands and swap/drop are distinct from the right-side action cluster
(`tgstation/code/_onclick/hud/human.dm:14-23`,
`tgstation/code/__DEFINES/hud.dm:219-244`).

## Proposed production path

Most visual work belongs in the pack: layout, slot borders, sprites, palette,
equipment grouping, chat wording/filter choices, and container selection.
The engine already accepts bounded grid/flex/absolute layout and atlas images;
see the engine's `docs/pack-ui/styles.md` and `docs/pack-ui/sdk.md`.

Three reusable host mechanisms support the designs:

1. **Reserved layout regions.** Declare edge docks and a world region. The
   trusted host sizes the canvas, preserves aspect and pixel scaling, and
   applies the same coordinate transform to rendering, hit testing and world
   anchors. HUD overlays stay attached to the world region. A wider browser
   does not grant additional server-disclosed visibility. User resizing and
   responsive layout stay host-side; no viewport measurements enter guests.
2. **Placed surfaces.** Declare a popover anchored to a package-local node,
   or a movable document window. The host manages geometry, clipping,
   stacking, dragging, focus and dismissal. Placement can flip at an edge and
   remains inside the assigned region. Closing a document still follows its
   native lifecycle; hiding a tray is pack presentation state.
3. **Transcript behavior.** Bounded stable entry identities and host-managed
   follow-end scrolling preserve the reader's position when reviewing older
   lines. Unread/jump-to-latest presentation, channel filters and repeated
   event grouping make chat useful without exposing scroll measurements.
   Current retention is only 64 native records, of which the pack shows 40
   (`lunatic/crates/lunatic-client/src/ui/mod.rs:285-297`, `ui/chat.ts:8-20`).

These are proposals, not newly supported SDK fields. A painted side panel can
be authored today, but actually reserving space for it needs the first host
mechanism. Current pack slots are isolated addon regions, not a world-layout
API. Existing context-point anchors do not anchor a popup to another UI node.

The raw DOM in this local concept tool is trusted tooling only. Production
retains the restricted QuickJS interpreter, validated JSON node/style grammar,
asset registry, package budgets, submitted-text boundary, server action checks,
and core-owned Escape. New host primitives do not expose arbitrary HTML, CSS,
browser JavaScript, URLs, coordinates or credentials to game operators.
See the engine's `docs/PACK-UI.md` and `docs/pack-ui/runtime.md`.

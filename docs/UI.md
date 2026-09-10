# Station interface

The station uses a cooler instrument-panel palette and the shipped sans,
mono and pixel faces. Flat borders, recognizable equipment artwork, clear
headings and operational status supply identity. Art references live in
[art-reference](art-reference/README.md); they are evidence for composition.
Production images stay under `assets/` and ship through the asset manifests.

| Skin | Composition |
|---|---|
| Gameplay | translucent communication and control regions over the station; restrained document cards; existing TG inventory frames and 32px artwork |
| Computers | square phosphor screen; device identity and artwork above structured drives, readers and diagnostics; physical controls stay separate from viewer close |
| Trusted shell/editor | stock engine surfaces; engine documentation owns their styling and interaction |

The body size is 13px, controls 12px, secondary metadata 11px and headings
15px. Headline measurements may be larger. Standard controls have 28px
minimum targets. Pixel faces use native-size multiples. Selected states use
outlines or explicit words; disabled actions retain disclosed explanations.

## Composition contract

`ui/theme/tokens.ts` owns every pack colour; `theme/roles.ts` retunes the
engine component kit. Computer roles are scoped under the computer skin.
`theme/kit.ts` owns common control geometry. Other sheets own surface-specific
layout. Pack rules cannot theme trusted recovery or editor controls.

`main.tsx` places communication and controls in separate bounded regions.
Chat history grows within the communication region, shrinking the inspection
stack. Inventory, worn equipment, target and actions share flow on the right.
Native item controls reserve the first action pins; long document action lists
expand inside a 240px scrolling region.
Storage and inspection history open as host windows. Their bodies scroll
without consuming the essential control region.

`view.ts:screen` roots every window and document: fixed toolbar, one growing
body scroller, fixed status/footer, optional modal overlay. Independent scrollers are the bounded inspection stack and the host action
list. Nested computer panes retain their
own height chain; `window-body` lays out its screen children as a flex column.
`overflow: hidden` clips; it is never a substitute for a scrolling body.

Each document uses the supplied title/name and status. Empty rosters show an
empty explanation. Material and stock shortages explain unavailable presses
beside the disclosed counts. A generic unavailable status does not invent a
power, access or proximity diagnosis that the provider did not disclose.

The computer and file workflow lives in [LAPTOP.md](LAPTOP.md). File workspace
modal ownership, readers and buffering use the engine's
`docs/pack-ui/components.md` and `docs/pack-ui/authoring.md` contracts.

## Authoring boundaries

Every player-visible sentence names a catalog key; [WORDS.md](WORDS.md) owns
the grammar. Inline style is placement only: position, edges, dimensions,
grid tracks/cells and animation. Data colours use an explicit `theme-lint:
allow` annotation. Every other look is a class in its theme sheet.

The engine kit class vocabulary is reserved. Pack classes are grouped by
surface: `hud-*`, inventory/body classes and matter `m*` in `theme/hud.ts`;
`inspect-*`, chat and reader classes in `theme/surfaces.ts`; `doc-*`, `mod-*`,
`action-*` and `window-*` in `theme/documents.ts`; `workspace-*`, `computer-*`
and `desktop-*` in `theme/workspace.ts`; `hover-*`, `mouse-*` and `overlay`
in `theme/overlay.ts`. Common fields and text roles live in `theme/kit.ts`.

Interactive IDs survive restyling. The engine's provider/file desktop tests
and pack fixtures are the record for pinned IDs: preserve `doc/<id>/<gen>/…`,
`hand/…`, `equipment/…`, `chat`, `lobby` and their registered command meaning.
Native providers validate actions. UI guests own only local presentation.

## Acceptance loop

[surface/state acceptance](ui/surfaces-acceptance.md) lists required states.
Fixtures under `ui/fixtures/` use disclosed provider data, bounded real-browser
input and result assertions. No fixture writes private guest state. Minimum
usable viewport is 1024×768; regular and wide checks use 1366×768 and 1600×1000.

From the engine checkout with `LUNATIC_PACK` set to this pack:

```sh
cargo run -q -p xtask -- build-ui
node tools/ui-lab.mjs shot <fixture> --lint
node tools/ui-lab.mjs shot all --check --lint
```

Read the resulting image, geometry and tree under `ui/fixtures/out/`.
Intended art changes update reviewed baselines with `shot <fixture> --update`.
Pack-art shots require a baked delivered atlas; synthetic engine assets verify
mechanism only. A rendering-environment mismatch skips pixel comparison while
mount, lint and interactions still run. Missing required baselines fail.
The engine's `docs/pack-ui/lab.md` owns fixture syntax and screenshot environment.

From this checkout, `node tools/test.mjs <engine>` checks theme rules,
localization and behavior. The engine gate runs the integrated pack checks.

# ui/ — the pack's interface

Restricted TypeScript/TSX the engine's host interprets: no DOM, browser
API, network, clock or per-frame hook. The engine's `docs/pack-ui/authoring.md`
is the guide (loop, kit, roles, what the grammar lacks); this file is
what THIS pack decided on top of it.

## File map

| Where | Owns |
|---|---|
| `main.tsx` | the HUD root: what is pinned to which edge, event dispatch |
| `view.ts` | `screen`, `panel`/`row`/`column`, `text`, `press`, `entry`, `select`, `icon`, and the id-to-command table every press registers in |
| `strings.ts`, `labels.ts` | the catalog key behind every word; `labelText` renders a server `Label` |
| `lobby.ts`, `chat.ts`, `inspect.ts`, `actions.ts`, `voice.ts`, `gesture.ts` | crew board and condition card, comms, examine and the tile menu, action strips |
| `inventory*.ts`, `doll.ts`, `slots.ts` | the tray, an opened container, the body-target figure |
| `documents*.ts`, `files*.ts`, `matter-block.ts` | one pane per document; the shared computer frameset, drives, editor, readers |
| `world-overlays.ts` | anchored speech and progress over the station |
| `model.ts`, `document-model.ts` | compile-time projections of the provider fields these screens read |
| `theme.ts`, `theme/` | the HUD sheet: `tokens.ts` (every colour), `roles.ts` (the kit retuned; `screenRoles` for a computer's glass), `kit.ts` (kit chrome and shared controls), `hud.ts`, `surfaces.ts`, `documents.ts`, `workspace.ts`, `overlay.ts`, `parts.ts` (edge/press/shade helpers) |
| `overlay/` | the hover-card addon: its own `main.tsx`, `manifest.json`, `styles.ts` over the same `theme/kit.ts` |
| `manifest.json`, `fonts.json`, `extensions.json` | the styles module, slots and key bindings; pack faces; the addon rows |
| `fixtures/` | disclosed views the lab and the engine tests render; `baselines/` the pictures; `out/` gitignored |
| `bundle.json`, `overlay.json` | build products, gitignored |

## Rules this pack keeps

- **`screen()` roots every window and document.** A node carrying
  `window`, and every document body, is `screen(id, parts)` from
  `view.ts`: the kit's `Screen` answered as a `panel`, bars that never
  shrink around the one `Scroll` at `<id>/body`. `axis` turns the body
  sideways when it holds screens of its own; `fit` sizes it to content.
  The one scroller outside a `screen()` is `inspect-stack`
  (`theme/surfaces.ts`); `overflow: "hidden"` elsewhere clips, never scrolls.
- **A colour lives in `theme/tokens.ts` and nowhere else.** Every rule
  draws with a token or `alpha(token, a)`. The kit is retuned through
  `theme/roles.ts`, never by restating a kit rule; a rule appended in
  `theme/*.ts` is for a class the roles cannot reach or a class of ours.
- **Inline `style` is placement only.** Allowed: `position`, `left`,
  `top`, `right`, `bottom`, `width`, `height`, `minWidth`, `maxWidth`,
  `minHeight`, `maxHeight`, `gridColumn`, `gridRow`,
  `gridTemplateColumns`, `gridTemplateRows`, `animation`. A look is a
  class in `theme/`. A value that must come from data (a substance's
  colour) says `theme-lint: allow` on its line or the one before.
- **Class namespaces.** The kit's vocabulary (the engine's
  `docs/pack-ui/components.md`) is reserved. Ours are prefixed by the
  sheet that owns them: `hud-*`, `slot-*`, `hand-*`, `worn-*`,
  `doll*`, `status*`, `storage-*`, `rune*` and the matter readouts
  (`m*`) in `hud.ts`; `inspect-*`, the comms (`composer-*`,
  `floating-chat`, `who*`, `tab`, `said`, `sys`), `actions-*` and
  `reader-*` in `surfaces.ts`; `doc-*`, `mod-*`, `action-*` and the
  `window-*` host parts in `documents.ts`; `workspace-*`, `computer-*`,
  `desktop-*` in `workspace.ts`; `hover-*`, `mouse-*`, `overlay` in
  `overlay.ts`; the typed controls (`entry`, `area`, `icon`, `fit`,
  `grow`, `mono`, `num`, `hint`, `marker`, `stock`, `pname`, `fname`,
  `fsize`) in `kit.ts`. A region's skin is a `within` rule under its
  class (`workspace.ts`, `SCREEN`), never a tag on each node.
- **Pinned ids.** The engine's tests press these by name; the id handed
  to the component is what survives a redesign
  (`rg '"doc/' <engine>/web/tests/pack-ui/providers.mjs pack-desktop.mjs`):
  `doc/<n>/1/product/<i>/vend`; `doc/<n>/1/editor/{save,title,conflict,revert,guard/discard,guard/cancel,body/<key>}`;
  `doc/<n>/1/drive/host/create{,/confirm,/stem,/ext}`,
  `doc/<n>/1/drive/host/file/<i>/copy`, `doc/<n>/1/drive/media{,/eject}`;
  `doc/<n>/1/{lid,close,controls,panes,power,heading,wallpaper,eject_cartridge}`;
  `doc/<n>/1/reader/content/{truncated,line/<i>}`; the roots `hud` and
  `lobby`.
- **Every word is a catalog key.** `strings.ts` binds `tfs("ui.…")`;
  `locale/<tag>.json` says it (`docs/WORDS.md`). `node
  tools/keyed-messages.mjs --check` fails on a literal that came back.
- **Fixtures before pixels.** A new surface ships a fixture in
  `fixtures/<name>.json` (schema: the engine's `docs/pack-ui/lab.md`)
  and a baseline recorded with `shot <name> --update`; the six today are
  `hud-idle`, `lobby`, `inventory-worn`, `hover-actions`,
  `laptop-desktop`, `laptop-files`.

## The loop and the checks

From the engine checkout with `LUNATIC_PACK` pointing here:

```sh
cargo run -q -p xtask -- build-ui                      # or: node tools/ui-lab.mjs serve --watch
node tools/ui-lab.mjs shot <fixture> --lint            # then Read ui/fixtures/out/<fixture>.png
node tools/ui-lab.mjs shot all --check                 # what the gate runs; --update when intended
npm --prefix web --silent run test:pack-ui             # renders and lints every fixture
```

From this checkout, `node tools/test.mjs <engine>` runs `theme-lint`
(colours and inline style), `keyed-messages --check` and every
`tools/test-*.mjs` against the engine's SDK; the engine's gate runs it
as `pack-node`. The layout lint is on in the build, the tests, the lab
and the gate; a finding is a failure, never a warning.

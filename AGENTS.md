# Tales from Space — content rules

This repository is the standalone game content pack for Tales from Space.
Read `README.md` before editing: it owns the repository layout, authoring
references, run commands, and spec-runner surface. Keep this file focused on
agent decisions rather than duplicating those details.

## Where to work

- The two fixed-name entrypoints are both optional and load in order:
  `content/audiences.luau` declares named delivery rosters, then
  `content/main.luau` makes every other top-level declaration. Files such as
  `capabilities.luau`, `part_tree.luau`, `palette.luau`, and `tuning.luau`
  establish pack-wide policy; roster directories under `content/` declare the
  game's prototypes and handlers.
- `content/lib/` contains shared Luau tables; see the rules below before adding
  or moving code there.
- `maps/` contains shipped RON maps. `tests/` contains player-facing Luau
  specs, including any inline RON fixtures they need.
- `assets/*.ron` are source manifests. `assets/tg-revision` pins the read-only
  `tgstation` source used by atlas baking; generated atlas output does not
  belong in this repository. Treat that checkout as reference only: never
  reconstruct its behavior from memory, and cite findings as `file:line`.
- `mod.toml` is the pack-owned identity, API version, native-edge, path, and
  requested-permission manifest. `modlist.toml` is the host-owned default mod
  list and approval grant. Do not confuse a request with an approval or
  broaden either merely to make content convenient.

## Engine boundary and validation

Mechanics (layout, running, spec commands) live in `README.md`. The
engine is the sibling checkout `../lunatic`; its `docs/` are the
contracts: `docs/SCRIPTING.md` is the v1 design, `docs/LUAU-API.md` the
surface these files CALL, `docs/CONTENT-SCHEMA.md` the fields they
DECLARE. Run the engine with `LUNATIC_PACK` pointing here.

Run engine commands from the engine checkout and set `LUNATIC_PACK` to this
pack's absolute path. A worktree under this repository's `.worktrees/` is not
a sibling of the engine, so do not derive the engine path with `..` there.
Use the narrowest filename-filtered spec while iterating, then the full pack
suite before completion; exact commands and filter semantics are in
`README.md`.

## Content design rules

- Content is the default home for game ideas: nouns (prototypes, rosters,
  constants, ids, maps, manifests) are data here; verbs at discrete event
  boundaries are Luau anchor handlers. `docs/LUAU-API.md` §4 is the
  as-built list of record and `idl/v1.json` freezes their names.
  An idea that seems to need per-tick native execution becomes a native
  system with data-driven knobs — never a faster handler.
- Game fiction never says "lunatic"; engine words stay out of content.
- Shared code lives in `content/lib/`. There is no `require`: a `lib/`
  file returns a table and the loader publishes it as a global named for
  the file (`lib/vessel.luau` -> `vessel`), before every roster and
  readable both at prototype time and inside a handler. Nothing in
  `lib/` may call `sim.define` — shared code publishes tables, rosters
  declare things. A gesture spelled out in two roster files belongs
  there instead; that duplication is what it exists to prevent. Because
  a `lib/` file may not `sim.define`, a shared answer is a FUNCTION
  there and the `Definition:handle` naming it lives in the roster file
  — `lib/radio_relay.luau` against `fixtures/transceiver.luau`,
  `fixtures/access_point.luau` and `fixtures/network_router.luau`.
- Radio policy is `lib/radio.luau` (every number, and who finally hears
  a `;` line) and `lib/radio_relay.luau` (what a tower, a wall box and a
  router each do to one crossing them). Nothing else decides who hears:
  a second path would be a second answer. The four relay stages are one
  published native edge, so `mod.toml` must keep `speech.relay` in
  `native_edges` or every registration fails at load
  (`docs/luau-api/radio-relay.md`).
- Specs (`tests/*_test.luau`) assert what a PLAYER could cause, through
  `t` — the same SimCommand seam the Rust harness uses. No raw entity
  handles, no component access, no direct spawn, and none should ever be
  added. Seed 0, `Tuning::default()` pinned, ticks-not-time, drain after
  step. Budget output (load ms, spec ms) is advisory wall clock; the
  hard budget is the host's fuel, counted per invocation and per mod
  per tick (lunatic's `crates/lunatic-server/src/fuel.rs`).
- Map RON inside Luau specs goes in `[==[ ... ]==]` long strings, not
  `[[ ... ]]` — rows like `"####"` can end a plain long string early
  (the Luau twin of Rust's raw-string trap).
- `content/tuning.luau` overrides engine feel constants; the engine's
  compiled defaults are what its tests pin.
- No player-visible sentence lives in code. `ui/*.ts` and every
  `content/**/*.luau` name a catalog key; `locale/<tag>.json` says it.
  One key is one finished sentence with its facts as `{placeholders}`,
  never a fragment joined with `..` — a per-outcome variant is its own
  key. `node tools/keyed-messages.mjs --check` fails on a literal that
  came back, and README's "Words" is the grammar and how to add a
  language.
- `ui/` owns every gameplay surface and binding in restricted TypeScript/TSX.
  Use the pack UI SDK; no real DOM, browser APIs, networking, guest clocks or
  per-frame script hooks. Native providers expose readouts and validated actions;
  they do not prescribe gameplay panels. Server Luau view models update from
  events and subscriptions.
- `editor/manifest.json` declares pack/mode palettes, property schemas, previews
  and bounded compositions of native edit operations. The trusted editor owns
  documents and undo; UI guests never receive editor drafts.

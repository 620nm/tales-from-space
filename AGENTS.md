# Tales from Space — content rules

The engine API you may call is `../lunatic/idl/generated/lunatic-v1.d.luau` (content) and `../lunatic/idl/generated/lunatic-spec.d.luau` (spec); read the generated signatures first.

This repository is the standalone game content pack for Tales from Space.
Read `README.md` before editing: it owns the repository layout, authoring
references, run commands, and spec-runner surface. Keep this file focused on
agent decisions rather than duplicating those details.
Read `docs/LUAU-DIALECT.md` before writing Luau.

Pre-alpha: broad, coordinated breaking changes are welcome. Migrate callers
and remove obsolete APIs/endpoints in the same change; do not add compatibility
aliases, shims or backports to preserve an old surface.

## Working together

- Use discovery agents to identify scope and exact files, confirm findings,
  then plan. Give fresh implementation agents small, nonoverlapping tasks with
  explicit file/function references and request terse, dense findings. Specify
  interfaces and asset art separately. Finish with an independent antagonistic
  review and resolve its findings. Shared-library ownership and atomic caller
  migrations follow `docs/LIB-CONTRACT.md`.
- Use isolated worktrees; preserve parallel agents' edits. The default location
  is `.worktrees/`; on this host use
  `/home/josh/.cache/codex-tmp/worktrees/<repo>-<branch>`. Keep git metadata
  writable. Other scratch belongs under `/home/josh/.cache/codex-tmp/`, never
  RAM-backed `/tmp`; build outputs keep their documented `target/` locations.
  Merge into clean `master`, then remove only your worktree, branch and scratch.
  If `master` is dirty, retain your work and report the blocked integration.
- Commit validated work incrementally with `type(scope): subject` (Conventional
  Commits): imperative, no period, subject at most 50 characters; put rationale
  in the body. Add `Co-authored-by: Name <email>` trailers identifying actual
  contributing humans or agents. Do not link session pages or use `gh` to
  create issues or PRs.
- Keep investigation narrow: targeted searches, line ranges and filtered logs.
  Ask about genuine ambiguity; do not dump entire files or unfiltered logs.
- `docs/*.md` is authoritative: fix stale contracts with the change, use present
  tense, and keep one home per fact with references elsewhere. Comments are
  concise contract/reference notes, not another policy source. Never read
  `docs/reports/` unless explicitly directed.

## Where to work

- The two fixed-name entrypoints are both optional and load in order:
  `content/audiences.luau` declares named delivery rosters, then
  `content/main.luau` makes every other top-level declaration. Files such as
  `capabilities.luau`, `part_tree.luau`, `compositions.luau`, and `tuning.luau`
  establish pack-wide policy; roster directories under `content/` declare the
  game's prototypes and handlers.
- `content/lib/` contains shared Luau tables; see the rules below before adding
  or moving code there. Assign shared-module file ownership with `docs/LIB-CONTRACT.md`.
- `reference/manifest.ron` catalogs preset files by ID. Its raw bodies stay
  outside trusted content; guest programs are standalone `.luau` sources.
  See `docs/scripting/reference-files.md` for authoring and disk seeding.
- `maps/` contains shipped RON maps (and may be empty). `tests/` contains
  player-facing Luau specs and `tests/maps/` contains their focused RON
  fixtures.
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
engine is the sibling checkout `../lunatic`. A bare `docs/…` names a file
HERE; an engine contract is always written "the engine's `docs/…`". The
engine's `docs/SCRIPTING.md` is the v1 design, the engine's
`docs/LUAU-API.md` the surface these files CALL, the engine's
`docs/CONTENT-SCHEMA.md` the fields they DECLARE. Five names sit on both
sides (`ATMOS`, `BIOLOGY`, `CHEMISTRY`, `GAMEMODES`, `POWER`): the engine owns the
mechanism, this pack the numbers it chose. Run the engine with
`LUNATIC_PACK` pointing here.

Run engine commands from the engine checkout and set `LUNATIC_PACK` to this
pack's absolute path. A worktree is not necessarily a sibling of the engine;
resolve the engine checkout explicitly instead of deriving it with `..` there.
Iterate with `cargo run -q -p lunatic-server -- test "$LUNATIC_PACK" <name>`
(name substring), `--load-only`, and the relevant named gate lanes.

`sh tools/check.sh` is THE GATE for this pack and runs from HERE: it finds the
engine through `LUNATIC_ENGINE` and checks this pack end to end (strict Luau,
the shared lints, the bake, content, maps, sprite names, the roster and the
editor palette, `ui/`, the node checks, the specs and the two live browser
fixtures). `README.md` §The gate lists every lane and what it proves. Validate
each commit with the checks covering its change; run the full gate once before
completion for runtime/content changes. Documentation-only changes need the
relevant documentation checks. Broaden or repeat checks when changes or failures
justify it. The engine's own
`tools/check.sh` is the other subject and asserts nothing about this pack, so
a green engine gate is not evidence here; the boundary between the two, and
what each proves, is the engine's `docs/gates.md`. The gate writes only this
repository's gitignored `target/`, never the engine's served root.

## Code Organization

- Target 5–15 files and 3–10 subdirectories per directory; split by feature or
  layer at 20–30 files, never exceed 50. Measure depth from the repository root:
  target 3–5 levels of handwritten source, at most 7.
- Apply those counts to `content/`, `ui/`, `tests/` and `tools/`. Generated
  trees (`ui/fixtures/out/`, the `ui/*.json` build products) are excluded.
- Target files below 300 lines; split before exceeding 1000. Keep this guide
  and `docs/**/*.md` at most 200 lines. Partition by feature and responsibility;
  shared typed modules belong in `content/lib/`, declarations in roster files.
- Name a roster file for its declared id (`items/<id>.luau`); the only allowance
  is numeric ordering prefix `NN_` (`access/10_engineering.luau`).
- Keep player-facing specs in `tests/**/*_test.luau`, shared spec helpers under
  `tests/helpers/`, and focused map fixtures under `tests/maps/`. Luau modules
  return explicit export tables; Rust crate/module/test conventions do not apply.

## Content design rules

- Content is the default home for game ideas: nouns (prototypes, rosters,
  constants, ids, maps, manifests) are data here; verbs at discrete event
  boundaries are Luau anchor handlers. The engine's `docs/LUAU-API.md` §4
  is the as-built list of record and `idl/v1.json` declares their names.
  An idea that seems to need per-tick native execution becomes a native
  system with data-driven knobs — never a faster handler.
- Game fiction never says "lunatic"; engine words stay out of content.
- Reuse existing domain records, primitives and helpers before adding new ones.
  Wrap reusable concepts in typed records instead of loose primitives and keep
  their operations together; coordinate exports through `docs/LIB-CONTRACT.md`.
- Avoid transient tables, closures and string churn in hot event handlers.
  Preallocate dense arrays with `table.create` when capacity is known; batch or
  chunk unavoidable growth where practical. Reuse or `table.clear` only buffers
  whose ownership excludes retained aliases and reentrant or yielding users;
  release stale references. These reduce garbage-collection pressure rather
  than guarantee allocation-free execution.
- Keep code human-readable; use distinct, descriptive names for types and shared
  helpers. Avoid generic names (`Data`, `State`) so agents can grep
  definitions and uses.
- Shared code lives in `content/lib/`; import its returned table with
  `local vessel = require("@lib/vessel")`. Dependencies are explicit in
  libraries too. Prototype sandboxes have imports but no `sim`; library
  initialization cannot call `sim.define`. Shared code exports tables,
  rosters declare things. A gesture spelled out in two roster files belongs
  there instead; that duplication is what it exists to prevent. Because
  a `lib/` file may not `sim.define`, a shared answer is a FUNCTION
  there and the `Definition:handle` naming it lives in the roster file
  — `lib/radio_relay.luau` against `fixtures/transceiver.luau`,
  `fixtures/access_point.luau` and `fixtures/network_router.luau`.
- Every trusted Luau source passes strict checking. From the engine run
  `node tools/luau.mjs check "$LUNATIC_PACK"` after edits; append `content`
  or `spec` and filenames to narrow it. One editor window offers both
  native APIs; the command enforces their separate runtime contexts.
  Authoring setup is the engine's `docs/luau-api/authoring.md`.
- Radio policy is `lib/radio.luau` (every number, and who finally hears
  a `;` line) and `lib/radio_relay.luau` (what a tower, a wall box and a
  router each do to one crossing them). Nothing else decides who hears:
  a second path would be a second answer. The four relay stages are one
  published native edge, so `mod.toml` must keep `speech.relay` in
  `native_edges` or every registration fails at load
  (the engine's `docs/luau-api/radio-relay.md`).
- Specs (`tests/*_test.luau`) assert what a PLAYER could cause, through
  `t` — the same SimCommand seam the Rust harness uses. No raw entity
  handles, no component access, no direct spawn, and none should ever be
  added. Seed 0, this pack's `content/tuning.luau` values pinned, drain
  after step. Elapsed waits use `t.run_seconds`; tick steps sequence
  events (`t.tick_hz` names the rate). Conversions follow the engine's
  `sim.ticks`/`sim.tick_hz` clock contract (the generated
  `lunatic-v1.d.luau` signatures, the engine's `docs/luau-api/runtime.md`).
  Budget output (load ms, spec ms) is advisory wall clock; the
  hard budget is the host's fuel, counted per invocation and per mod
  per game second (lunatic's `crates/lunatic-server/src/fuel.rs`).
- Map RON inside Luau specs goes in `[==[ ... ]==]` long strings, not
  `[[ ... ]]` — rows like `"####"` can end a plain long string early
  (the Luau twin of Rust's raw-string trap).
- `content/tuning.luau` overrides engine feel constants; the engine's
  compiled defaults are what its tests pin.
- No player-visible sentence lives in code. `ui/*.ts` and every
  `content/**/*.luau` name a catalog key; `locale/<tag>.json` says it.
  One key is one finished sentence with its facts as `{placeholders}`,
  never a fragment joined with `..` — a per-outcome variant is its own
  key, and a sentence two files both say is `lib.<area>.<name>`, hoisted
  once. `node tools/keyed-messages.mjs --check` fails on a literal that
  came back, and `docs/WORDS.md` is the grammar and how to add a
  language.
- `ui/` owns every gameplay surface and binding in restricted TypeScript/TSX.
  `ui/AGENTS.md` routes surfaces to owners, narrow commands and acceptance
  evidence. `docs/UI.md` owns pack composition and authoring rules; the
  engine's `docs/pack-ui/authoring.md` owns the SDK. Native providers expose
  disclosed readouts and validated actions. Layout findings fail validation.
- `editor/manifest.json` declares pack/mode palettes, property schemas, previews
  and bounded compositions of native edit operations. The trusted editor owns
  documents and undo; UI guests never receive editor drafts.

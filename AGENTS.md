# Tales from Space — content rules

Mechanics (layout, running, spec commands) live in `tfs/README.md`.
Contracts: `docs/SCRIPTING.md` is the v1 design and
`docs/LUAU-API.md` is the as-built surface these files use today.

- Content is the default home for game ideas: nouns (prototypes, rosters,
  constants, ids, maps, manifests) are data here; verbs at discrete event
  boundaries are Luau anchor handlers. `docs/LUAU-API.md` §4 is the
  as-built list of record and `idl/v1.json` freezes their names.
  An idea that seems to need per-tick native execution becomes a native
  system with data-driven knobs — never a faster handler.
- Game fiction never says "lunatic"; engine words stay out of content.
- Specs (`tests/*_test.luau`) assert what a PLAYER could cause, through
  `t` — the same SimCommand seam the Rust harness uses. No raw entity
  handles, no component access, no direct spawn, and none should ever be
  added. Seed 0, `Tuning::default()` pinned, ticks-not-time, drain after
  step. Budget output is advisory until fuel metering (segment K1).
- Map RON inside Luau specs goes in `[==[ ... ]==]` long strings, not
  `[[ ... ]]` — rows like `"####"` can end a plain long string early
  (the Luau twin of Rust's raw-string trap).
- `content/tuning.luau` overrides engine feel constants; the engine's
  compiled defaults are what its tests pin.
- tg UI reuse filter (docs/TGUI.md): adopt a tg window's data contract
  only where the window itself is good; dead-economy shim fields mean a
  small native window instead.

# Tales from Space — content rules

Mechanics (layout, running, spec commands) live in `tfs/README.md`.
Contracts: `docs/SCRIPTING.md` is the ratified v1 destination;
`docs/LUAU-API.md` is the as-built v0 surface these files use today.

- Content is the default home for game ideas: nouns (prototypes, rosters,
  constants, ids, maps, manifests) are data here; verbs at discrete event
  boundaries are Luau hooks (`on_interact`, `on_use`, `on_bump`,
  `on_attack`, `on_mob_life`, `on_use_self`, `on_pull`, `on_throw_land`,
  `on_rupture`, `on_life_state`, `on_threshold`, `on_seated`,
  `on_unseated` today — docs/LUAU-API.md §4 is the list of record;
  anchors after the SCRIPTING.md Appendix E cutover).
  An idea that seems to need per-tick native execution becomes a native
  system with data-driven knobs — never a faster hook.
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
- Interface declarations are ordered native mechanism modules
  (`docs/TGUI.md`), never a game-named engine window or a script-authored
  state blob.

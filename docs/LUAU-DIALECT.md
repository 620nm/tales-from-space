# Trusted Luau authoring card

This pack uses Luau, not Lua 5.1/5.4 or Roblox's runtime. Content and specs
have different host APIs (`sim` and `t`); guest controller programs have
another sandbox (see [scripting/controllers.md](scripting/controllers.md)).

- `continue` is supported; `goto` is not. `//` means floor division.
- Backtick interpolation is supported, but player-visible sentences use
  catalog keys and placeholders, never interpolated prose; see [WORDS.md](WORDS.md).
- Strict checking is inherited from the root `.luaurc`; a `--!strict`
  pragma is not mandatory. Do not declare globals: use locals and returned
  module tables. Type function parameters/results and use `export type`
  for types consumers need; imports preserve typed exports.
- `content/.luaurc` maps `@lib` to `content/lib/`:
  `local vessel = require("@lib/vessel")`. Libraries import their own
  dependencies. Specs use `@helpers` from `tests/.luaurc`, for example
  `local ui_controls = require("@helpers/ui_controls")`.

Prototype files and shared libraries return tables. The two optional
entrypoints and spec scripts are exceptions; they need not return tables.
Prototype evaluation has imports but no `sim`; register roster behavior
under `if sim ~= nil then`, using `sim.define(...)` and the resulting
`Definition:handle(...)`. Shared handlers are library functions registered
by rosters. Library initialization cannot call `sim.define`; a function
such as `vessel.attach` may call it later from roster registration.

Behavior loading: optional `content/audiences.luau` (delivery rosters),
then optional `content/main.luau` (other top-level declarations), then
remaining libraries, then roster files in deterministic path order within
each roster. Explicit imports may evaluate libraries earlier. Libraries
are evaluated once per environment; runtime imports read cached tables.
See the engine's `docs/luau-api/loading.md:30` and
`crates/lunatic-server/src/script/loader.rs:424`.

The trusted content sandbox exposes a whitelist, not the full Luau library:

- Standard globals: `assert`, `buffer`, `error`, `ipairs`, `math`, `next`,
  `pairs`, `pcall`, `print`, `rawequal`, `select`, `string`, `table`,
  `tonumber`, `tostring`, `type`, `typeof`, `utf8`, `vector`, `xpcall`.
- Library tables are frozen and only listed members are copied. Check
  the member whitelist before assuming a familiar function exists.
- No `io`, `os`, `debug`, `package`, `coroutine`, `load`, `loadstring`,
  `dofile`, `getfenv`, `setfenv`, `setmetatable`, or Roblox services.
  `require` is the host's module importer, not Lua package loading.
- `math.random` uses the owner's round-seeded stream and rejects draws
  during definition. `math.randomseed` exists but always errors.
- Yield through `sim.sleep` / `sim.do_after` only inside a host task;
  durations are integer ticks, from 1 through 60 seconds' worth of ticks.

Sandbox sources (paths relative to the engine checkout):
`crates/lunatic-server/src/script/idl_generated.rs:19` (globals),
`crates/lunatic-server/src/script/idl_generated.rs:435` (members),
`crates/lunatic-server/src/script/luau_environment.rs:78` (projection/freeze),
`crates/lunatic-server/src/script/luau_environment.rs:12` (random), and
`crates/lunatic-server/src/script/luau_environment.rs:105` (task yields).

Validate from the engine checkout with `LUNATIC_PACK` set to this pack's
absolute path: `node tools/luau.mjs check "$LUNATIC_PACK"`.

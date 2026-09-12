# Game modes

*Which modes this pack declares, what each one changes, and the shift the two of
them share. The mechanism — what a mode file may declare, how the engine loads
it, the `neutral` fallback — is the engine's `docs/GAMEMODES.md`. This file is
the policy.*

Two modes, in `content/gamemodes/`. No id here is engine vocabulary: the engine
spells only `neutral`, and everything below is a name this pack invented.

| Policy | Space Station (default) | Free Build |
|---|---|---|
| `id` | `space_station` | `free_build` |
| Joining | Lobby and job selection | Body spawns on connection |
| Spawn gear | The chosen job's outfit | Station Engineer's outfit, without the job |
| Disconnecting | Body remains and can be reclaimed | Body and carried inventory despawn |
| Incapacitation | Respawn offered on a dead body (`inanimate`) | Respawn offered in critical state or death (`uncontrollable`) |
| Respawning | Returns to the lobby on a fresh Mind | Seats a new body at once |
| Vending | Roundstart quantities deplete | Every shelf remains stocked forever |
| Sky | Rolled (below) | Rolled (below) |
| Playtesting | — | The mode a posted map boots into |
| Shift | One hour | One hour — the same hour |

Space Station is the home for imported station systems and the station shift
itself. Free Build is a development construction playground; its rules exist to
shorten the edit/test loop, not to become exceptions inside station gameplay,
which is why it runs the same hour and the same map refresh.

```sh
cargo run -p lunatic-server                          # Space Station
cargo run -p lunatic-server -- --mode free_build
```

## Free Build's gear

Nobody picks a job in `free_build`, so `rules.outfit = "engineer"` issues the
Station Engineer's standard kit — jumpsuit, ID, stocked toolbelt, metal and
tiles — to every body that spawns. It is the gear, not the job: no slot is
taken and the crew manifest is unchanged. Somebody who spawns to build should
already be holding the tools.

Both modes name `rules.body = "human"`. Without a plan on the mode or on the
job there would be nothing to seat.

## The shift

Both modes declare the same `rules.shift` table and bind the same two handlers.
`rules.shift` is pack data the engine never reads — `content/lib/shift.luau` is
its sole interpreter, and the mode files are its only callers.

```luau
shift_minutes = 60,
grace_seconds = 30,
warnings = { 600, 300, 60 },   -- seconds of shift REMAINING
announcer = "Charter Command",
channel = "Common",
```

The hour is this pack's opinion and it is the same opinion under every mode,
which is why it lives in one library rather than once per mode file. Free Build
ends on the same hour deliberately: a sandbox whose map never refreshes is a
sandbox nobody can reset, and a mode whose rules were an exception would be a
second answer to when a round ends.

**Each `warnings` entry is seconds of shift REMAINING**, so `600` announces ten
minutes out. `shift.on_second` counts `clock.second`, announces at each mark,
and calls `sim.round.finish({ grace_seconds })` on exactly the second
`shift_minutes` is up — exactly one second, because the clock keeps publishing
through the finalization grace and every later second would otherwise ask
again. `shift.on_end` says the closing line on `round.end`.

`shift.validate` runs at definition time under the script host, so a bad number
is a `--load-only` failure rather than a shift that quietly never ends. It
refuses a non-whole `shift_minutes` outside 1..1440, a `grace_seconds` outside
0..120, a sparse or repeating `warnings` list, a mark that is not a whole minute
of remaining time inside the shift, and an empty `announcer` or `channel`.

`grace_seconds` runs from 0 to 120 — the pack's ceiling is the engine's
`MAX_ROUND_END_GRACE_SECS` exactly, refused here rather than clamped there, so a
mode asking for more would otherwise be shortened without being told.

Nothing in `shift.luau` may raise: a handler that throws is disabled for the
rest of the shift, and one runtime error before the last second would be a round
that never ends. It reads no round-scoped state, which stops being legal the
moment `round.end` returns.

### Who hears it

`announcer` and `channel` must be the pair `mod.toml`'s `[notifications]` block
declares — `Charter Command` on `Common`. Delivery is `sim.message.notify` to
the `lunatic/tfs:round` audience (`content/audiences.luau`), which resolves to
`sim.query.minds()`: every continuity identity the round minted, so a player who
ghosted or is watching without a body still hears the shift end.

The three lines are catalog keys, whole sentences with their facts as
placeholders (`docs/WORDS.md`): `lunatic/tfs:shift_warning`,
`lunatic/tfs:shift_final_minute` and `lunatic/tfs:shift_over`. "In one minute"
is its own key rather than a plural with a one in it.

`mod.toml` selects `lifecycle.clock` and `lifecycle.round_end` in
`native_edges`, and not `lifecycle.round_start`: nothing here handles the start
edge.

## Skies

`rules.environment.rolls` names profiles from `content/environments/`. Selection
happens before geometry, on the round's seeded RNG, and map tags decide which
entries are eligible.

| Mode | Terrestrial map | Otherwise |
|---|---|---|
| `space_station` | `cold_outdoors` | `dead_space` 4, `orbit` 3, `sunward` 1, `microgravity` 1 |
| `free_build` | `cold_outdoors` | `dead_space` 1, `microgravity` 1 |

The space profiles use the `space_backdrop` atlas background. `dead_space`,
`orbit`, and `sunward` retain standard gravity (`9.80665` m/s²); `microgravity`
has zero gravity and the same cold vacuum as `dead_space`. Its weight is one in
both modes, so it is available whenever the map leaves gravity unconstrained.

Each roll entry is a filter as well as a weight. Every `required_tags` value
must be present on the map, and every `excluded_tags` value must be absent. The
ordinary entries that pass those tag filters and the map's saved physical
preferences are the candidates. A `fallback = true` entry is considered only
when no ordinary entry passes; it is unconditional for tags but still must
satisfy the map's physical preferences. If no candidate survives, the map is
rejected before the round starts.

The four shipped maps save `gravity_m_s2: Exact(9.80665)` so their existing
stations continue to use walking movement. A new map omits `environment` by
default; that leaves its physical preferences unconstrained and allows the
mode to choose microgravity. These preferences filter profiles.

An optional `atmosphere_blend: Some("map_air")` instead fixes the ambient recipe.
The map's own blend definition takes precedence over a pack blend with the same
ID. The game chooses an atmospheric profile for the remaining conditions and
keeps the authored composition and air temperature. Without a fixed blend,
`atmosphere: Exact(true)` requires air and lets the game choose its mix; the
current terrestrial profile supplies `refrigerated_air`. Outdoor initial air
and atmospheric recovery use the chosen or authored recipe. Painted initial
air remains a tile-specific choice.

## Playtesting

`free_build` sets `playtest = true`, so a map posted to `POST /maps/playtest`
boots into it when the operator names no `--playtest-mode`. A mapper wants to
walk the station they just drew with the tools to poke at it, not to queue at a
job board for a shift they are not playing. At most one mode in the pack may
claim the flag.

## Both files are evaluated twice

The native mode loader reads a `gamemodes/` file in a bare VM with no `sim` and
no shared library, purely to extract `rules`. The script host then loads the
same file as content, where `sim` and the `lib/` globals exist. That is the
whole reason for the `if sim ~= nil` guard around `shift.validate` and the
`sim.define("behavior", ...)` binding — it is not defence, just the difference
between the two passes.

Each mode binds its behavior with `prototype = content.id`, so the mode hears
`clock.second` and `round.end` on its own id with no `global_handlers` grant.

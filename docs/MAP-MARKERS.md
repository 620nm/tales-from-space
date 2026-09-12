# Map markers

Map markers are ordinary map structures that carry pack policy. They are
invisible in play, remain in the authoritative world for trusted scripts
until a hook consumes one, and are copied, pasted and moved by the same editor
operations as every other structure. The marker and placement contracts live
in the engine's `docs/content-schema/placement.md`, `docs/luau-api/queries.md`
and `docs/luau-api/lifecycle.md`.

This pack ships two marker prototypes:

| Prototype | Use | Placement knobs |
|---|---|---|
| `player_spawn` | Candidate location for a crew body | `weight`, `jobs`, `roles` |
| `threat_spawn` | Candidate location for a later encounter | `weight` |

Both are in the editor's `Map Markers` section and use rough debugging icons
from `assets/originals/art/markers/`. The icons identify marker intent while a
map is being authored; the live marker entity is hidden from player views.

## Player locations

Each mode binds one `round.spawn` transform. `content/lib/map_markers.luau`
filters the live `player_spawn` handles, sums their usable weights, makes one
seeded draw, and writes the selected tile to `ev.at`. The selection order is
stable, so a fixed map and seed replay the same result.

`weight` defaults to `1`. A value of `0` disables that point; the editor and
placement schema cap it at `1,000,000`. An empty `jobs` or `roles` list means
any value. Lists are comma separated, trimmed, lowercase tokens. A malformed
list or an unknown job makes that marker ineligible, which keeps a typo from
silently widening the spawn pool.

The Space Station mode supplies the default role `crew`; Free Build supplies
`builder`. A mode or another pack policy may store a role on the Mind's
`spawn_role` ScriptVar before selecting a point. The current marker policy
therefore supports both job filters and pack-owned role filters without
putting game vocabulary in the engine.

For example, a medical bay can use `jobs = "medic"` and `weight = 99`, while
a bar seat can leave `jobs` empty and use `weight = 1`. The relative weights
describe selection pressure among the candidates that pass the job and role
filters; they do not promise a percentage while other candidates are present.

If no candidate survives filtering, admission fails closed and no body is
created. A map should provide at least one positive point for every job and
role combination its mode admits.

## Threat locations

`map_markers.threat_location()` performs the same weighted selection over
`threat_spawn`. `map_markers.spawn_threat(definition)` chooses a location and
then calls the typed `sim.mob.spawn({ definition, at })` command. The command
validates the mob roster, tile and per-round spawn limit and records the
result. The helper returns `false` when no location is available.

Threat markers do not create encounters at map load. An actorless world
handler, such as a round or clock hook, calls `spawn_threat` and chooses the
mob definition. This keeps secluded points useful for dynamic threats without
adding an automatic encounter schedule to the map format.

## Initialization hooks

The marker structures name their own script behavior and receive the ordinary
`entity.initialize.done` completion hook. The hook runs once after the map
placement's properties have seeded the marker vars. A custom marker may use
`sim.entity.spawn` at `ev.entity.tile` and
`sim.entity.despawn({ entity = ev.entity })` to replace itself with generated
contents. Initialization effects are buffered and bounded by the engine's
lifecycle authority. A failed hook discards its effects and removes the failed
entity.

This is the same seam used by other map-authored structures, so future locker
loadouts and marker-specific setup remain content behavior. Per-tick scans and
encounter simulation stay in the engine's generic mechanisms.

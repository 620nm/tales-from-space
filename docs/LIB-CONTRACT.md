# Shared library contract

`content/lib/` owns answers reused by rosters: policy tables, constructors and
handler helpers. Keep one answer here when two roster files need the same gesture.
Import returned tables explicitly with `require("@lib/name")`, including inside
libraries; dependencies are never implicit globals. See [README.md](../README.md)
for loading, authoring and validation, and [AGENTS.md](../AGENTS.md) for decisions.

Library initialization must not call `sim.define`: prototype sandboxes have no
`sim`. Helpers may use native APIs when invoked in the appropriate roster or
handler context. For example, `vessel.attach(spec)` calls `sim.define` and binds
handlers when a roster invokes it; `item_actions.attach` and `writing.attach`
bind handlers to a supplied `Definition`. Exporting such functions is legal.
Prototype and handler environments have separate caches and capabilities; an
exported table is not a promise of shared runtime identity or immutability.

## Ownership and assignment map

Each row is one module ownership unit under `content/lib/`; caller paths below
are relative to `content/`. Caller groups locate affected files, not blanket
write grants: expand groups and imports into concrete filenames in task prompts.
The source owns exact signatures; this table records responsibility and shape.

| Module file | Responsibility and public surface shape | Caller files or groups to resolve |
| --- | --- | --- |
| `action_rules.luau` | Gesture selectors; `Selector`/`Action` types; `fact`, `kind`, `deck`, `exposed_deck(network)`, `network(network)`, `primary`, `attack` return declarative records. | `lib/vessel.luau`; importing files in `items/{electronics,gear,leisure,piping,surgery,tools,vessels}/` |
| `blast.luau` | Detonation effects, in call order; `apply(at)` deals the two-band blast damage, `cast(at)` plays the flash choreography and blast sound, `burst(at)` throws the fragment volley. | `items/weapons/frag_grenade.luau` |
| `cards.luau` | Deck vocabulary; `FACES`, `NAMES`, `states`, `state_sprites` tables; `slug`, `read`, `count`, `picture` helpers. | `items/leisure/{card,card_deck}.luau` |
| `controller.luau` | Guest controller execution and completions; `Voice`/`Event` types; `run` returns boolean; `device`, `message`, `service_send_done`, `door`, `pressure`, `button` handlers. | `fixtures/{access_point,air_alarm,airlock,airlock_button,bidirectional_vent}.luau` |
| `decal_paints.luau` | Floor-decal paint vocabulary and decal opacity; `colors` array of `{id, hex}`, `defaults` array of ids, numeric `trim_opacity`/`mark_opacity`. | `compositions.luau`; `items/tools/decal_painter.luau` |
| `device_queue.luau` | Bounded paced device packets; `Packet` type; `clear`, boolean `send`, `button`, `completion`. | `lib/controller.luau` |
| `item_actions.luau` | Possession action presentation; `Spec` type; `attach(definition, spec, use)` and boolean `internals(ev)`. | `items/tools/welder.luau`; `items/piping/{emergency_tank,oxygen_tank,rpd}.luau` |
| `map_markers.luau` | Spawn-marker selection; `player_spawn` returns `{at}`; `threat_location` returns optional tile; `initialize`, boolean `spawn_threat`. | `fixtures/{player_spawn,threat_spawn}.luau`; `gamemodes/{free_build,space_station}.luau` |
| `netmsg.luau` | Device payload vocabulary and light priority; `Flag`/`LightFlag`/`Hazard` types, kind constants, `flags`, `standing`; constructors, validator, `winner`, `report_hazard`. | `fixtures/{air_alarm,air_scrubber,apc,light,vent}.luau` |
| `network.luau` | Device-network examine wording; `line(node, noun, member)` returns optional `Message`. | `fixtures/{air_alarm,apc,network_router}.luau` |
| `pipe_paints.luau` | Paint vocabulary; `colors` array of `{name, hex}`, `defaults` array of names. | `compositions.luau`; `items/piping/{pipe_painter,rpd}.luau` |
| `physical_profiles.luau` | Pack-owned loose-body motion records; `loose_item1kg` supplies mass, collision, and public-contact defaults for throwable items. | Every prototype under `items/`; heavier bodies and fixtures declare explicit overrides. |
| `preparation.luau` | Fair role allocation; `allocate(ev)` returns `{assignments: {AllocationAssignment}}`. | `gamemodes/space_station.luau` |
| `printing.luau` | Printer resources, batch/tick limits; scalar constants and `costs()` returning per-output `{resource, amount}` rows. | `fixtures/{fax,photocopier}.luau` |
| `program_slot.luau` | Live guest binding, persistence and attribution; `run(machine, id, env)` returns unknown result or nil and adds `env.mem`. | `lib/{controller,radio_relay}.luau` |
| `radio.luau` | All radio numbers and final listener policy; channel/key tables, range constants, `radius_for`, `garble`, `keyed_words`, `status_line`, `deliver` returning `{listeners}`. | `lib/radio_relay.luau`; `fixtures/transceiver.luau`; `items/{electronics/encryption_key,gear/headset}.luau` |
| `radio_relay.luau` | Relay receive/read/carry/send policy; `keyed_to` predicate and four handlers returning stage-specific records. | `fixtures/{access_point,network_router,transceiver}.luau` |
| `residue_kinds.luau` | Blast residue vocabulary; `shard_kind`/`cloudy_kind` numbers, `pellets_per_volley`/`cloudy_per_blast` counts, per-kind tier ladders, `ash_moles`/`ash_temp_k` matter spec. | `residue_appearances.luau`; `items/weapons/frag_grenade.luau`; `lib/blast.luau` |
| `service.luau` | Fax service names and payload bounds; string/number constants, `chunks(text)` returning string array. | `fixtures/fax.luau` |
| `shift.luau` | Shift validation, warnings and finish request; `Rules` type; `validate`, `announce`, `on_second`, `on_end`. | `gamemodes/{free_build,space_station}.luau` |
| `stock_parts.luau` | Component efficiency ladder; `efficiency` indexed by tier; `rung(tier)` returns `{tier, efficiency}`. | `items/electronics/{capacitor,encryption_key,matter_bin,micro_laser,network_card,scanning_module,servo}.luau` |
| `thermal.luau` | Pipe heat-exchange tuning; numeric `he_coefficient`, `he_deadband_k`. | `items/piping/he_pipe.luau` |
| `vessel.luau` | Shared vessel actions and transfers; `Spec.open_to_pour` requires an open seal for condensed pours; optional-number `moles`/`headspace_l`, `actions(spec)` returns action array, `attach` returns `Definition`, and `charge(spec,self,user,source,at)` reuses the sealed gas-valve stroke. | Importing `items/vessels/*.luau`; `items/tools/{fire_extinguisher,mop}.luau`; `items/materials/resin_pellet.luau` |
| `writing.luau` | Bounded paper projection and append; `Fragment`/`PaperView` types, limits, `fragments`, `view`, boolean `open`/`update`/`append`, `attach`. | `fixtures/{fax,photocopier}.luau`; `items/leisure/{paper,four_color_pen,crayon_*}.luau` |

## Parallel-agent contract

Task prompts assign exclusive concrete file sets from this table, including
caller files, relevant specs and catalog files. One writer owns each module per
wave; each caller file also has one writer even when it imports several modules.
Check current `@lib/` imports before assigning: the caller map can grow.

Consumers treat exported keys, exported types and function signatures as frozen
for their wave. Do not change a key's shape in the same parallel wave as its callers:
a function cannot become a table, nor may parameters, result fields, optionality
or array/record structure drift while consumers are being written.
One serial owner changes the module and migrates existing callers atomically,
then validates and publishes the exact surface before the next consumer wave.
Do not add a compatibility layer. Coordinate new exports with the module owner
to avoid key collisions; add the agreed surface before dependent work starts.
Existing callers must remain valid at the handoff.
This is an editing contract, not a claim that runtime tables are frozen.

Keep exports narrow and typed; describe record fields, units, nil/false outcomes
and mutation where they affect callers. Put new shared behavior in its owning
module, or assign a new module explicitly when no row owns it, and update this
map. Keep roster declarations at the call site and player-visible wording in
catalog keys. Run the README's strict checks and applicable specs for code edits.

# Mop bucket and janitorial cart

`content/items/janitorial/{mop_bucket,janitor_trolley}.luau`, on
`content/lib/wheeled_tub.luau`. Decisions read as in `docs/janitorial/mop.md`.
tg path: `janitor.dm` is `code/game/objects/structures/janitor.dm`.

## Why items

Both are items that refuse a bare-hand pickup. Item mechanisms already cover
them: native storage is the rack, `show_contents` with `stowed_sprite` is
`update_overlays`, `fill_sprites` is the water, a pull rolls them, and tile reach
covers their matter. As structures they would need engine widening for stowing
held items, taking out one item, a third `item_slot` kind, and reach to a
vessel that is not docked.

The price is density: walkers pass through a cart and do not shove it. Dense
items need engine work in `crates/lunatic-server/src/sim/movement/step_admission.rs`
`loose_structure_at`, which queries structures only, and is left out.

## Tub

| tg | Behaviour | Decision |
| --- | --- | --- |
| `janitor.dm:1` | At least 1 u counts as holding | luau: `MINIMUM_MOL`, 0.025 mol |
| `janitor.dm:4-7,54-57` | Names, sprites | api |
| `janitor.dm:8` | Dense | omitted: see above |
| `janitor.dm:9` | Syringe transfer stub | omitted: nothing calls it here |
| `janitor.dm:15,68` | 100 u; cart holds 2.5 times that | adapted: 1667 mL and 4167 mL, tg's ratio to the head |
| `janitor.dm:18-29` | Screen tips | api: the pour row shows only for a pouring vessel or the mop; the dump row for a crowbar |
| `janitor.dm:31-44` | Secondary wets a mop | adapted, reversed: secondary pours the mop or vessel in |
| `janitor.dm:43` | Slosh sound | api: same sound |
| `janitor.dm:48-51` | Water overlay | api: `fill_sprites` |
| `janitor.dm:251-263` | Crowbar dumps after 5 s | luau: `dump_seconds = 5`, `sim.matter.spill`, reported from `matter.spill.done`; a user who walks or a tub that rolls stops it. The mop bucket dumps too, adapted: its mop cannot empty it here |
| Not in tg | Sealed or gas-only source | luau: refused with a line |
| Not in tg | Overflow | api: `sim.matter.pour` lands the excess on the deck; `matter.pour.done` tells the player |
| `spray.dm:43` | A spray bottle fills from the cart | omitted: primary stows the bottle and secondary pours it in; no gesture draws from a tub |

## Rack

| tg | Behaviour | Decision |
| --- | --- | --- |
| `janitor.dm:58-64` | Six typed slots, four signs | adapted: `storage = 9`, the same count, untyped |
| `janitor.dm:69,72` | `janitor_devices` | omitted: no custodial locator (`radar.dm:296-306`) |
| `janitor.dm:73-78` | Contents die with the cart | api: native |
| `janitor.dm:81-112` | Entered and Exited track slots | api: native storage |
| `janitor.dm:114-135` | Examine lists the contents | adapted: the open panel shows them |
| `janitor.dm:177-249` | Click stows a matching tool | api: native stow, any item up to nine |
| `janitor.dm:179-181` etc. | One of each kind | omitted: slots are untyped; the count still bounds it |
| `janitor.dm:205-208` | Trash bag insertable check | omitted: no trash bag prototype |
| `janitor.dm:265-273` | Secondary inserts into the bag | omitted: as the bag |
| `janitor.dm:275-341` | Radial picks a tool | adapted: `alt_primary` opens the storage panel |
| `janitor.dm:343-348` | Secondary takes the mop | adapted: the panel; secondary with empty hands does nothing |
| `janitor.dm:356` | Radial needs a capable user | api: native panel reach |
| `janitor.dm:359-372` | Overlays per tool | api: mop, spray and replacer sprites; bag, broom and sign prototypes are absent |

Primary clicks with any held item stow it, so pouring and dumping are on the
secondary gesture, where tg already keeps its mop verb.

The rack's untyped click is an engine gap: storage has no `accepts` filter, so
stowing runs ahead of every handler and the pack cannot turn a held item away.
A generic `accepts` selector on item storage closes it, and the typed slots with
it.

Every lift off the deck asks the item first, so a drag into a bag meets the same
refusal as a click.

Other carried items draw nothing on the cart. A `stowed_sprite` is per
prototype, so a mop in another `show_contents` container draws the cart's mop.

The card's primary row reads too heavy and names Ctrl-click: the native Take is
false here, and Pull is a reserved gesture no action row can declare, so no
item shows a Pull row of its own.

## Vendor

`content/machines/tool_vendor.luau` stocks both, standing in for
`cargo/packs/service.dm:30-50`.

The janicart vehicle is omitted: no vehicle exists to carry it.

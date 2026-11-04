-- A cadaver chamber (tg's morgue, code/game/objects/structures/morgue.dm):
-- the thing medbay keeps the dead in until somebody fetches them. Here it is a
-- closet in the shape of a slab cabinet: open, it can be walked onto and lain
-- on; shut, it holds what lay there (`fixtures/cadaver_chamber.luau`), and a
-- pass a second reads what it holds (`lib/closets/chamber_watch.luau`).
--
-- It runs on station power, which tg's does not: `morgue.dm` declares a plain
-- `/obj/structure` with no `use_power`, so a tg morgue cools and beeps whatever
-- Engineering is doing. A chamber here is on a cord like the vending machines,
-- so one somebody has cut the power to stops preserving, stops beeping and goes
-- dark: a thing nobody can switch off is a thing nobody can sabotage.
--
-- Opening slides what it held out onto the tile it faces, a step each through
-- the ordinary movement rules (`open()`, :134-147; `lib/closets/tray.luau`),
-- and closing takes back what lies there (`close()`, :149-169). Divergence: tg
-- `forceMove`s onto that tile whatever stands there (:144); here a wall or a
-- dense thing keeps what cannot step out on the chamber's own tile, which the
-- close also gathers from.
--
-- NOT PORTED:
-- - The tray as a thing (`/obj/structure/tray/m_tray`, :536-628): a dense,
--   anchored structure there would refuse the very step out, so the contents
--   land on the bare tile, nothing marks it, and clicking the tile does not
--   close the chamber. A body goes in by the closet stuff drag, not a
--   two-second lay onto the tray (:589-600).
-- - Aiming the placement (:233): a container has one facing, so `morgue*_s`.
-- - The sealed air (:278-298): a closed holder supplies room air, so a living
--   occupant does not suffocate.
-- - Preservation of loose and nested organs: an organ condition holds seated
--   organs only, so a chamber preserves the corpses in it and nothing else.
-- - The stocked corpse (`dead_body_placer`, code/modules/mapping/
--   mapping_helpers.dm:975-1026): a pack has no way to mint a dressed, dead body.
-- - The `morgue4` lamp (:404-406) for an occupant who has not stopped: a lit state
--   would take their push, air and speech (`chamber_watch`), so the alarm says so.
-- - A lit chamber's occupants in staff's projected contents, and the view of a
--   dead occupant who has not ghosted: the engine serves both through the exact
--   `closed` state alone, so the lamps cost them.
-- - The lock and sixty-second breakout (:112-128, only the crematorium locks),
--   the alt-click that silences the beeper (:378-381), and the crematorium.
local closet_data = require("@lib/closets/data")
local closet_rows = require("@lib/closets/rows")

local lit_states = { closet_data.chamber_items_state, closet_data.chamber_bodies_state }

return {
    id = "cadaver_chamber",
    script = "cadaver_chamber",
    -- Closets draw under items (low_object in content/compositions.luau).
    visual_layer = "low_object",
    energy_network = "power",
    name_label = "lunatic/tfs:entity.cadaver_chamber.name",
    name = "cadaver chamber",
    sprite = "morgue1_s",
    dense = true,
    opaque = false,
    -- Corded furniture: each placement must have a powered socket
    -- (`docs/POWER.md`, "Outlets and cords").
    corded = true,
    states = { "closed", lit_states[1], lit_states[2], "open" },
    scripted_states = { "closed", lit_states[1], lit_states[2] },
    -- `morgue3` for things with no mob in them, `morgue2` for a dead one
    -- (:391-410). The sheet ships no dark state: a chamber with no feed wears
    -- its shut face, and no art is invented for it.
    state_sprites = {
        open = "morgue0_s",
        [closet_data.chamber_items_state] = "morgue3_s",
        [closet_data.chamber_bodies_state] = "morgue2_s",
    },
    passable = { "open" },
    actions = closet_rows.door_actions(lit_states),
    container = {
        capacity = closet_data.item_capacity,
        body_capacity = closet_data.body_capacity,
        max_body_size = closet_data.max_body_size,
        closed = "closed",
        open = "open",
        open_sound = "morgue_clank",
        close_sound = "morgue_clank",
        stock = {},
    },
    examine = {
        flavor = "A refrigerated cabinet with a slab in it. Used to keep "
            .. "bodies in until someone fetches them.",
    },
}

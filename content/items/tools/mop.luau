local physical_profiles = require("@lib/physical_profiles")
local vessel = require("@lib/vessel")

-- The mop: the one thing on the station that takes a mess OFF the deck
-- rather than putting one there. tg: `/obj/item/mop`
-- (code/game/objects/items/mop.dm:1-47); every row is docs/janitorial/mop.md.
--
-- It is a vessel, and `lib/vessel.luau` owns both gestures: the deck fills
-- the head, the head is wrung into whatever you point it at. Beads and a
-- settled puddle both lift, and so do the loose solids a tile has gathered,
-- in proportion, until the head is full.
--
-- tg's head is `max_reagent_volume = 15` (mop.dm:21), a unit of nothing in
-- particular; here a spill is real litres and the head is a real quarter
-- litre. The stroke is tg's `mopspeed` (mop.dm:22).
local content = {
    id = "mop",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.mop.name",
    name = "mop",
    sprite = "mop",
    inhand_sprite = { "held_mop_l", "held_mop_r" },
    category = "tools",
    examine = {
        flavor = "A grey head on a long handle. It answers the deck and "
            .. "nothing else, and it is the only answer the deck has.",
    },
    -- `force`, `throwforce`, `throw_speed`, `throw_range` (mop.dm:10-13).
    force = 8,
    throw_force = 10,
    throw_speed = 3,
    throw_range = 7,
    -- How much the HEAD holds, which is how much one stroke can lift:
    -- what is on the tile goes in until it is full, and the rest of the
    -- mess stays where it is.
    volume_ml = 250,
    -- What it draws stowed in a janitor's trolley (janitor.dm:363-364).
    stowed_sprite = "janitor_trolley_mop",
    -- Clicking the bucket has to reach the handler rather than picking it
    -- up: wringing out is a thing you do TO the thing you named.
    acts_on_items = true,
}

local vessel_spec: vessel.Spec = {
    id = content.id,
    noun = "mop",
    -- Liquid, and the loose solids resting with it. Ice is fast to the deck.
    phases = { "solid", "liquid" },
    -- A wring is not a measured pour: the head comes out.
    pour = { units = "all", message = "lunatic/tfs:items.mop.you_wring_the_mop_out" },
    soak = {
        seconds = 1.5,
        pinned_solids = { water = true },
        message = "lunatic/tfs:items.mop.you_run_the_mop_over",
        floating = "lunatic/tfs:items.mop.you_chase_the_beads",
        deposit = "lunatic/tfs:items.mop.you_scrape_the_deposit",
        dry = "lunatic/tfs:items.mop.the_deck_here_is_dry",
        ground = "lunatic/tfs:items.mop.you_run_the_mop_over_ground",
        ground_dry = "lunatic/tfs:items.mop.the_ground_here_is_dry",
        full = "lunatic/tfs:items.mop.the_mop_is_soaked_through",
    },
}
content.actions = vessel.actions(vessel_spec)

if sim ~= nil then
    vessel.attach(vessel_spec)
end

return content

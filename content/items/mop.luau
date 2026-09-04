-- The mop: the one thing on the station that takes a puddle OFF the
-- deck rather than putting one there.
--
-- It is a vessel, and that is the whole trick. A tile's matter is a
-- body of matter like a beaker's (docs/luau-api/matter.md), so mopping
-- is the transfer every vessel already does with the ends swapped and
-- only the liquid phase named: the deck fills the head, the head is
-- wrung into whatever you point it at. Neither gesture is spelled out
-- here -- `lib/vessel.luau` owns both -- and this file is the numbers
-- and the nouns that make them a mop.
--
-- WHAT CAME FROM TG AND WHAT DID NOT (mop.dm:20-22, which declares
-- `max_reagent_volume = 15` and `mopspeed = 1.5 SECONDS`). The SHAPE is
-- tg's: one head, holding a fixed amount, filled a stroke at a time off
-- the floor. The numbers are not, and cannot be. A tg unit is a
-- millilitre of nothing in particular, so tg's head holds fifteen of
-- them and its floors hold a decal; here a spill is real litres of a
-- real substance and a fifteen-millilitre head would be a teaspoon
-- against a flood. A quarter of a litre is a real mop head. tg's
-- second-and-a-half stroke has no seam to hang on either: there is no
-- timed action here yet, so one click is one stroke, and the cadence is
-- a player's arm rather than a timer.
local content = {
    id = "mop",
    name = "mop",
    sprite = "mop",
    category = "tools",
    examine = {
        flavor = "A grey head on a long handle. It answers the deck and "
            .. "nothing else, and it is the only answer the deck has.",
    },
    -- How much the HEAD holds, which is how much one stroke can lift:
    -- what is on the tile goes in until it is full, and the rest of the
    -- puddle stays where it is.
    volume_ml = 250,
    -- Clicking the bucket has to reach the hook rather than picking it
    -- up: wringing out is a thing you do TO the thing you named.
    acts_on_items = true,
}

if sim ~= nil then
    vessel.attach({
        id = content.id,
        noun = "mop",
        -- A mop takes up liquid and leaves the salt on the deck.
        phases = { "liquid" },
        -- A wring is not a measured pour: the head comes out.
        pour = { units = "all", message = "You wring the mop out." },
        soak = {
            message = "You run the mop over the deck.",
            dry = "The deck here is dry.",
            full = "The mop is soaked through.",
        },
    })
end

return content

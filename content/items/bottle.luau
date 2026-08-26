-- The bottle: fifty units with a neck on it. Same size as the beaker
-- and a different shape of thing to carry it in -- a beaker is what you
-- mix in and a bottle is what you put on a shelf afterwards.
--
-- The shell is tg's `volume = 50`, and the shell is the whole of what
-- it holds; the picture and the fill prefix are both tg's `bottle`
-- (bottle.dm:6-7; `volume = 50` at :12, `fill_icon_thresholds` at
-- :13).
--
-- The gestures are the vessel's rather than this file's
-- (`lib/vessel.luau`): your own tile is a swig, another vessel within
-- reach is a pour, the deck is a spill.
--
-- The FOURTH is the one only a corked vessel gets to keep: held against
-- a fixture that is standing full of gas, a SEALED vessel charges
-- instead of pouring, and an open one is refused. That is where the
-- permanent gases enter chemistry at all -- oxygen, nitrogen, hydrogen
-- and fluorine left the dispenser shelf when the twins were folded,
-- because a press of one over an open glass is a press into the room
-- (docs/BENCH.md 4) -- and it is what makes the gas-share recipes
-- reachable: carbon dioxide wants fifty kilopascals of oxygen over its
-- carbon, nitrous oxide a hundred over its ammonia, and no beaker on
-- the bench can carry either. The bottle is the vessel this station has
-- that says `sealed`, so the bottle is the one that can.
local content = {
    id = "bottle",
    name = "bottle",
    sprite = "bottle",
    examine = {
        flavor = "Glass with a neck on it, made for carrying rather than "
            .. "mixing. What ends up on the shelf.",
    },
    -- tg's bottle: `volume = 50` (cups/bottle.dm:12), the cup base's
    -- own figure. One unit is one millilitre.
    volume_ml = 50,
    -- A neck has a stopper in it. What a shelf keeps is corked, so what
    -- is in it stays in it: a bottle does not breathe with the room the
    -- way an open beaker does, and what ferments inside one builds a
    -- pressure of its own (docs/BENCH.md 2). Pouring, drinking and
    -- spilling are all you pulling the cork, and none of them asks
    -- about the lid -- the seal is what the bottle does while nobody is
    -- handling it.
    sealed = true,
    fill_sprites = {
        { 1, "bottle_fill_1" },
        { 20, "bottle_fill_20" },
        { 40, "bottle_fill_40" },
        { 60, "bottle_fill_60" },
        { 80, "bottle_fill_80" },
        { 100, "bottle_fill_100" },
    },
    acts_on_items = true,
    -- The preconfigurations, each a prototype of its own
    -- (`bottle.iodine`) derived from everything above
    -- (docs/CONTENT-SCHEMA.md 1.1a). A bottle with a charge in it is
    -- the same glass with a different label, which is a line of data
    -- and not a second file.
    variants = {
        -- Iodine crystals: how iodine reaches the bench, since it is
        -- not a dispenser button (docs/CHEMISTRY.md 7). Sealed like
        -- every bottle, so what stands over the crystals is their own
        -- vapour at the sublimation line -- a few pascals of violet at
        -- room temperature -- and nothing escapes until it is tipped
        -- out. Fifty units of tg's bottle
        -- (reagent_containers/cups/bottle.dm:12) is 1.25 mol; a bottle
        -- of crystals carries a tenth of that, 0.125 mol = 32 g =
        -- 6.4 mL of the fifty.
        iodine = {
            name = "bottle (iodine)",
            contents = { iodine = 0.125 },
            examine = {
                flavor = "Glass with a neck on it. Grey-black crystals, and a "
                    .. "violet haze over them that was not there a moment ago.",
            },
        },
    },
}

if sim ~= nil then
    vessel.attach({
        id = content.id,
        noun = "bottle",
        phases = { "liquid", "solid" },
        -- tg's cup default `amount_per_transfer_from_this = 10`
        -- (_cup.dm:4), which is also the beaker's gesture.
        pour = { units = 10 },
        sip = { units = 2 },
        spill = true,
    })
end

return content

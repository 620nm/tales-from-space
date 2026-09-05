-- A floor drain: a grated hole in the deck that takes standing water
-- off it, and the only thing on this station that does.
--
-- tg HAS NO FLOOR DRAIN. A water spill there is a `wet_floor` decal on
-- a timer (`code/game/objects/effects/decals/cleanable/misc.dm`,
-- `other_reagents.dm:138-147`), so there is nothing to drain and
-- nothing to port: `code/modules/plumbing/` is all machines that feed
-- each other, none of which stands open to the room. What is borrowed
-- is the PICTURE, from the one machine in that tree doing the same job
-- -- the chemical disposer, "Breaks down chemicals and annihilates
-- them" (plumbers/destroyer.dm:4-8) -- and nothing else. tg's disposer
-- eats 5 u a second off a plumbing duct; this eats half a litre a
-- second off the deck, and the two numbers have nothing to say to each
-- other.
--
-- HALF A LITRE A SECOND is a mop that never stops. A crewman with a
-- bucket lifts a quarter of a litre a stroke, so one grating is worth
-- about two people mopping -- fast enough that a knocked-over carboy is
-- a chore rather than a shift, slow enough that a real flood outruns it
-- and somebody still has to shut the door.
--
-- WHAT IT CANNOT TAKE is the film. The engine drains only the liquid
-- standing ABOVE the depth surface tension holds a puddle at
-- (../lunatic/docs/matter-world/flow.md), which is about 3.3 mm of
-- water: a drain that took the film would leave its tile drier than any
-- neighbour could make it and pull on the room forever. So a drained
-- deck is a damp deck, and the wet-boot problem is the mop's.
--
-- Solids stay too. Ice does not level and does not drain; it sits on
-- the grating until something melts it.
--
-- NOTHING UNBOLTS IT. The grating is the top of a hole, and this pack
-- ships no gesture that puts a hole in a deck, so there is no wrench
-- step here and no fitting to carry: a drain is where the station was
-- built with one.
return {
    id = "floor_drain",
    name = "floor drain",
    sprite = "floor_drain",
    -- Flush with the deck: you walk over it, and you see the pipe and
    -- cable painted under it like any other deck fitting.
    dense = false,
    opaque = false,
    examine = {
        flavor = "A grated hole in the deck. Whatever is spilled goes down it, eventually.",
    },
    atmos = {
        -- The mechanism with no mouth: a drain stands ON the deck
        -- rather than in a run, so it names no layer, no facing and no
        -- switch (../lunatic/docs/content-schema/structures.md, `sink`).
        device = "sink",
        -- Litres a second, off the tile it stands on. `rate_lps` is the
        -- block's one spelling for a rate; `rate_l_per_s` is refused by
        -- name so a near miss cannot leave a drain quietly running at
        -- its default.
        rate_lps = 0.5,
    },
}

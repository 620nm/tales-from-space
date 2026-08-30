-- The bare beaker: empty off the shelf, and the vessel everything else
-- on a chem bench is poured into. Fifty millilitres of glass, which is
-- the whole of what it holds.
--
-- Three gestures, all of them one click with it in your active hand:
-- your own tile is a swig, another vessel within reach is a pour, and
-- the deck beside you is a spill. A fourth -- charging off a gas line --
-- is refused, because a mouth with no stopper in it lets the charge
-- back out on the next exchange.
--
-- None of that is spelled out here. It is one implementation for every
-- vessel in `lib/vessel.luau`, and this file is the numbers and the
-- nouns that make it a beaker.
local content = {
    id = "beaker",
    name = "beaker",
    sprite = "beaker",
    examine = {
        flavor = "Graduated glass with a lip on it. Whatever a bench is "
            .. "doing, it is doing it in one of these.",
    },
    inhand_sprite = { "held_beaker_l", "held_beaker_r" },
    -- How big the GLASS is, which is the whole of how much it holds:
    -- what fits is what the liquid takes up, and the space left above
    -- it is what a vapour saturates -- and therefore how fast an open
    -- beaker of anything volatile gives itself to the room. tg's cup
    -- base declares `volume = 50` (reagent_containers/cups/_cup.dm:6);
    -- one of tg's units is one millilitre.
    volume_ml = 50,
    -- What it shows through the glass. tg's beaker declares
    -- `fill_icon_thresholds = list(0, 1, 20, 40, 60, 80, 100)`
    -- (_cup.dm:452) against the fill sheet's `beaker1`..`beaker100`;
    -- the 0 stop is dropped because nothing on that sheet answers to
    -- it, and below 1% tg draws no fill either.
    fill_sprites = {
        { 1, "beaker_fill_1" },
        { 20, "beaker_fill_20" },
        { 40, "beaker_fill_40" },
        { 60, "beaker_fill_60" },
        { 80, "beaker_fill_80" },
        { 100, "beaker_fill_100" },
    },
    -- Clicking another loose vessel has to reach the hook rather than
    -- picking it up: pouring is a thing you do TO the thing you named.
    acts_on_items = true,
    -- What the infirmary keeps on the shelf, as a variant of the glass
    -- rather than a copy of this file (docs/CONTENT-SCHEMA.md 1.1a):
    -- `beaker.libital` is a beaker in every way but what is in it, so
    -- it wears the same gestures out of the same `lib/vessel.luau`.
    variants = {
        libital = {
            name = "beaker (libital)",
            contents = { water = 0.20, libital = 0.15 },
        },
        salt = {
            name = "beaker (salt)",
            contents = { salt = 0.80 },
        },
        -- The two the steam generator is about: one it will take and
        -- one it will not. Plain water is the thing a station has most
        -- of; ethanol is a volatile that is emphatically not water
        -- (it boils at 351.5 K, so it CAN cross a mouth and is
        -- therefore a real negative rather than a substance that could
        -- never have left the glass anyway).
        water = {
            name = "beaker (water)",
            contents = { water = 0.60 },
        },
        ethanol = {
            name = "beaker (ethanol)",
            contents = { ethanol = 0.60 },
        },
    },
}

if sim ~= nil then
    vessel.attach({
        id = content.id,
        noun = "beaker",
        phases = { "liquid", "solid" },
        -- tg's cup default `amount_per_transfer_from_this = 10`
        -- (_cup.dm:4). Two units is a mouthful.
        pour = { units = 10 },
        sip = { units = 2 },
        spill = true,
    })
end

return content

-- Gameplay-feel constants, tunable to taste (docs/POWER.md). Missing
-- fields fall back to the engine's hard-coded defaults — and the test
-- suite pins THOSE defaults, so tuning here never breaks tests.
return {
    -- How far an appliance's power cord reaches, in path cells (never
    -- through walls; closed doors count as walls). Engine default: 6.
    cord_range = 6,

    -- Net gas flow across a tile edge per atmos tick (moles) above
    -- which decompression wind drags loose things and mobs downwind.
    -- Engine default: 1.0 (a venting room gusts along its whole
    -- length; ordinary door equalization stays still).
    wind_threshold_mol = 1.0,

    -- How grey each turf class is: the fraction of a black body's
    -- photons its hull face emits into the sky -- and, by Kirchhoff,
    -- absorbs out of the sunlight. 0 is a perfect mirror, 1 a perfect
    -- radiator, and every number here is between them.
    --
    -- 0.5 is a middling grey body: bare or painted steel, which is what
    -- an ordinary deck and the bare hull plate under it are. 0.03 is
    -- multilayer insulation -- the crinkled gold blanket a real
    -- spacecraft wears -- and it is on the reinforced turfs on purpose:
    -- reinforcement is what a room gets when it is meant to contain
    -- something dangerous, and a room built to hold an experiment in is
    -- built to hold its heat in too. A reinforced chamber cools about
    -- seventeen times slower than a tiled one.
    --
    -- Engine defaults: 0.5 / 0.5 / 0.03 / 0.5 / 0.03.
    emissivity = {
        floor = 0.5,
        plating = 0.5,
        reinforced_floor = 0.03,
        wall = 0.5,
        reinforced_wall = 0.03,
    },
}

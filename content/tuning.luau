-- Gameplay-feel constants, tunable to taste (docs/POWER.md). Missing
-- fields fall back to the engine's hard-coded defaults — and the test
-- suite pins THOSE defaults, so tuning here never breaks tests.
return {
    -- How far an appliance's power cord reaches, in path cells (never
    -- through walls; closed doors count as walls). Engine default: 6.
    cord_range = 6,

    -- Dynamic pressure of the wind over a tile (Pa) above which loose
    -- items slide one tile downwind, and above which a body is dragged
    -- off its feet. q = 1/2 rho v^2 off that tile's own air, so a
    -- vented room stops pushing on its own -- nothing switches the wind
    -- off, it runs out. Drag sits UNDER slide: a body standing up in
    -- the airstream is a sail, a toolbox on the deck is a brick. Engine
    -- defaults: 0.008 and 0.004 (a venting corridor takes both; a
    -- swinging door and a crewman's own wake take neither).
    wind_slide_pa = 0.008,
    wind_drag_pa = 0.004,

    -- How much air (m/s) a body pushes ahead of it per step it walks,
    -- and the fraction of that a thrown thing pushes. This is what
    -- makes a crowded room mix faster than an empty one. Engine
    -- defaults: 0.02 and 0.01 -- calibrated so a walker's wake stays
    -- under both thresholds above (docs/MATTER-WORLD.md §6).
    stir_mob_mps = 0.02,
    stir_throw_scale = 0.01,

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

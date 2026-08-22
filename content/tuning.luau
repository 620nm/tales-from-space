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
    -- under both thresholds above (docs/MATTER.md §13).
    stir_mob_mps = 0.02,
    stir_throw_scale = 0.01,
}

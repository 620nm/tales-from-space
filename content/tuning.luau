-- Gameplay-feel constants, tunable to taste (docs/POWER.md). Missing
-- fields fall back to the engine's hard-coded defaults, which the
-- engine's own tests pin. This pack's specs boot with THESE values, so
-- a change here can move what they measure.
return {
    -- How far an appliance's power cord reaches, in path cells (never
    -- through walls; closed doors count as walls). Engine default: 6.
    cord_range = 6,

    -- Dynamic pressure of the wind over a tile (Pa) above which loose
    -- items slide one tile downwind, and above which a body is dragged
    -- off its feet. q = 1/2 rho v^2 off that tile's own air, so a
    -- vented room stops pushing on its own -- nothing switches the wind
    -- off, it runs out. Drag sits UNDER slide: a body standing up in
    -- the airstream is a sail, a toolbox on the deck is a brick. A
    -- breach at the end of a long corridor peaks near 0.75 beside the
    -- hole, drags seven tiles back and slides four; a three-tile closet
    -- peaks near 0.35 one tile in and 0.09 two in; a door onto a vacuumed
    -- room peaks near 1.1. A vent (~0.08), a scrubber (~0.05), a door
    -- evening out 10 kPa (~0.02) and a crewman's own wake (~2.4e-4)
    -- take neither. Engine defaults: 0.3 and 0.15.
    wind_slide_pa = 0.3,
    wind_drag_pa = 0.15,

    -- How much air (m/s) a body pushes ahead of it per step it walks,
    -- and the fraction of that a thrown thing pushes. This is what
    -- makes a crowded room mix faster than an empty one. Engine
    -- defaults: 0.02 and 0.01 -- calibrated so a walker's wake stays
    -- under both thresholds above (docs/MATTER-WORLD.md §6).
    stir_mob_mps = 0.02,
    stir_throw_scale = 0.01,

    -- The pressure (kPa) this station calls SAFE to stand in. It is a
    -- number about legibility rather than about the body: a machine
    -- emptying the tile it is bolted to wears its warning picture only
    -- once that air has fallen below this, so an air scrubber turned
    -- round in a full room looks like the ordinary machine it is being
    -- used as, and a corridor going red means a corridor actually
    -- emptying. Raise it and the station cries wolf; drop it and the
    -- warning arrives too late to walk out on. Engine default: 85.
    safe_pressure_kpa = 85.0,

    -- How long it takes to lay a dragged body out on a surface it can
    -- rest on -- an operating table, a cadaver drawer's slab. The whole
    -- of that gesture's feel: raise it and a surgeon works for their
    -- patient, drop it and a body on a table is a click. It is a wait
    -- the victim can walk out of, which is the point. Engine default:
    -- 2.0, tg's own number for putting somebody somewhere
    -- (code/modules/recycling/disposal/bin.dm:225).
    lay_body_secs = 2.0,

    -- The two bands a vent or a scrubber sorts the air on its own tile
    -- into, once an atmos pass, and reports over the network when it
    -- crosses one (docs/atmos/hazard-sensing.md). DEADLY is air nobody
    -- survives working in; UNBREATHABLE is air nobody should be asked
    -- to. Everything else is `none`, and staying in a band says
    -- nothing -- a room that is still on fire is not news twice.
    --
    -- The temperatures are round Celsius rather than a port: 100 and
    -- -30 for the outer pair, 50 and -20 for the inner. tg's own limits
    -- are about a body that is already cooking; an instrument on a wall
    -- is supposed to say so before that. `health_at_least` is the 0..=4
    -- rating the tile's own mix earns on the same scale a hazard
    -- placard is drawn from (docs/matter/hazard.md), and 3 is where a
    -- room full of something reads as lethal rather than merely foul.
    --
    -- The two pressures are the room the LUNGS need: 85 kPa is the same
    -- number `safe_pressure_kpa` above is, and 16 kPa is the partial
    -- pressure of everything a substance file flagged breathable. The
    -- engine spells no gas here, which is why raising the floor is a
    -- decision about the station rather than about oxygen.
    --
    -- Engine defaults: exactly these. Both are moved together or not at
    -- all -- a band whose floor is not under its ceiling is ignored
    -- outright and the engine's pair stands.
    hazard = {
        deadly = {
            temp_above_k = 373.15,
            temp_below_k = 243.15,
            health_at_least = 3,
        },
        unbreathable = {
            temp_above_k = 323.15,
            temp_below_k = 253.15,
            pressure_below_kpa = 85.0,
            breathable_below_kpa = 16.0,
        },
    },

}

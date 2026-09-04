-- Ice in a beaker, in a room at twenty degrees.
--
-- The glass is the pack's ordinary fifty-millilitre beaker and the ice
-- is a Matter Blend the map names on the placement
-- (content/blends/ice_block.luau). Two moles of water at 0.917 g/mL is
-- under forty millilitres, so it FITS -- a solid has a volume and a
-- shell it does not fit in is a shell the charge would have to argue
-- with.
--
-- Three sentences:
--   * the glass arrives holding a solid, at the temperature the blend
--     names, with no liquid in it at all
--   * left standing in a warm room it MELTS. Nobody touches it; the
--     deck and the air do the work
--   * and the water is still the same water: what left the lump
--     arrived in the puddle under it

t.world([==[(
    name: "ice bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    blends: {
        // Two moles, frozen, ten degrees under melting -- the `:solid`
        // suffix said out loud, as content/blends/ice_block.luau says it.
        "ice_block": (rows: [("water:solid", 2.0)], temperature_k: 263.15, amount: total),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    items: [
        (3, 1, "beaker", { "blend": "ice_block" }),
    ],
)]==], 0)

local p = t.join()
t.tick()

local LUMP_MOL = 2.0
local FROZEN_K = 263.15
local MELT_K = 273.15

local function near(got, want, tol, what)
    assert(got ~= nil, what .. ": nothing was answered")
    assert(math.abs(got - want) <= tol,
        ("%s: wanted %g, got %g"):format(what, want, got))
end

local glass = t.target_at(3, 1, "beaker")

-- ---------------------------------------------------------------
-- Out of the freezer: a solid, and cold.
-- ---------------------------------------------------------------
local cold = t.vessel(glass)
assert(cold ~= nil, "a beaker has an inside")
assert(cold.contents.water ~= nil, "the map put water in it")
near(cold.contents.water.solid, LUMP_MOL, 1e-9, "two moles of it, frozen")
assert(cold.contents.water.liquid == nil, "and not a drop of liquid yet")
near(cold.temp_k, FROZEN_K, 0.5, "at the temperature the blend names")
assert(cold.temp_k < MELT_K, "which is under the melt, or it would not be ice")

-- ---------------------------------------------------------------
-- Leave it on the bench. The room is ordinary air at 20 C and the
-- lump has nowhere to be but warmer, so it crosses the melt and
-- starts going. Half a minute of shift, and nobody touched it.
-- ---------------------------------------------------------------
t.run_ticks(700)

local thawing = t.vessel(glass)
local w = thawing.contents.water
assert(w ~= nil, "the water did not go anywhere")
assert(w.liquid ~= nil and w.liquid > 0.0,
    "there is meltwater in the glass: " .. tostring(w.liquid))
assert(w.solid ~= nil and w.solid < LUMP_MOL,
    "and the lump is smaller than it was: " .. tostring(w.solid))
assert(thawing.temp_k > cold.temp_k, "because the room warmed it")

-- ---------------------------------------------------------------
-- One substance, two states, one amount. Melting is a phase moving,
-- not matter appearing -- but the glass is OPEN, so a little of it
-- leaves as vapour and the books only balance if the room is on
-- them. A settling sweep takes the last thousandths off tiles that
-- were left holding less than the engine has an opinion about, and
-- `t.nullified` is where those go: gas that fell under the floor,
-- told apart from gas that went out through a grille.
-- ---------------------------------------------------------------
local in_glass = (w.solid or 0.0) + (w.liquid or 0.0) + (w.gas or 0.0)
assert(in_glass < LUMP_MOL, "the open glass exhaled a little of it")

local in_room = 0.0
for x = 1, 3 do
    in_room = in_room + (t.room_gas(x, 1).water or 0.0)
end
assert(in_room > 0.0, "and the room over the bench is where it went: " .. in_room)

local swept = t.nullified().water or 0.0
near(in_glass + in_room + swept, LUMP_MOL, 1e-6,
    "glass plus room plus sweep is the lump that was set down")

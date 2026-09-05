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
--
-- Then it goes into the dispenser's dock, because the panel over a
-- docked vessel is where a lump of ice is a WEIGHT rather than a
-- volume, and grams are what a crewman would guess at.

t.world([==[(
    name: "ice bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
    },
    blends: {
        // Two moles, frozen, ten degrees under melting -- the `:solid`
        // suffix said out loud, as content/blends/ice_block.luau says it.
        "ice_block": (rows: [("water:solid", 2.0)], temperature_k: 263.15, amount: total),
    },
    rows: [
        "#######",
        "#o..a.#",
        "#######",
    ],
    spawns: [(1, 1)],
    items: [
        (3, 1, "beaker", { "blend": "ice_block" }),
    ],
    // A dispenser at the end of the bench, powered off the room's own
    // circuit: the dock is the only window in the pack that opens over
    // a beaker, and the last section of this spec reads the lump
    // through it.
    machines: [(5, 1, "chem_dispenser")],
    cables: [(1, 1, 1), (2, 1, 1), (3, 1, 1), (4, 1, 1), (5, 1, 1)],
)]==], 0)

local p = t.join()
t.tick()

local LUMP_MOL = 2.0
local FROZEN_K = 263.15
local MELT_K = 273.15

-- A document's words are labels: `{id=…}` for one the engine names,
-- `{text=…}` for one content wrote (docs/tgui/labels.md).
local function word(label)
    if type(label) ~= "table" then return label end
    return label.id or label.text
end

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
for x = 1, 5 do
    in_room = in_room + (t.room_gas(x, 1).water or 0.0)
end
assert(in_room > 0.0, "and the room over the bench is where it went: " .. in_room)

local swept = t.nullified().water or 0.0
near(in_glass + in_room + swept, LUMP_MOL, 1e-6,
    "glass plus room plus sweep is the lump that was set down")

-- ---------------------------------------------------------------
-- AND WHAT IT WEIGHS.
--
-- The block over a docked vessel carries the mass of every state and
-- every row beside the volume (docs/tgui/matter-block.md), because a
-- lump is a thing you would pick up and millilitres are not what you
-- would pick it up by. Water is 18.015 g a mole in any state it
-- stands in, so each number here is its own moles times that -- a
-- registry that had lost water's molar mass to the default would be
-- out by a factor of five and a half, not by a rounding.
-- ---------------------------------------------------------------
local MOLAR_MASS_G = 18.015

local function block(ui, section)
    for _, b in ipairs(ui.matter or {}) do
        if word(b.section) == section then
            return b
        end
    end
    return nil
end

local function phase_of(b, phase)
    for _, st in ipairs(b and b.states or {}) do
        if st.phase == phase then
            return st
        end
    end
    return nil
end

local function named(st, name)
    for _, r in ipairs(st and st.rows or {}) do
        if r.name == name then
            return r
        end
    end
    return nil
end

t.move(p, "east")
t.run_ticks(5)
t.click(p, 3, 1, glass)
t.run_ticks(2)
assert(t.hands(p).held == "beaker", "the glass comes off the bench")
t.move(p, "east")
t.run_ticks(5)
t.move(p, "east")
t.run_ticks(5)

local dispenser = t.target_at(5, 1)
assert(dispenser ~= nil, "a dispenser stands at the end of the bench")
t.click(p, 5, 1, dispenser)
t.tick()
assert(t.hands(p).held == nil, "clicking the dock with it puts it IN")
t.click(p, 5, 1, dispenser)
t.tick()

local contents = block(t.ui(p), "dock.contents")
assert(contents ~= nil, "the panel draws what the docked glass is holding")

local lump = phase_of(contents, "solid")
assert(lump ~= nil, "there is still a lump of it in there")
assert(lump.moles > 0.0, "with moles on the state: " .. tostring(lump.moles))
near(lump.mass_g, lump.moles * MOLAR_MASS_G, 1e-6,
    "the lump weighs water's own molar mass a mole")
local ice_row = named(lump, "water")
assert(ice_row ~= nil, "and the one row in it is the water")
near(ice_row.mass_g, ice_row.moles * MOLAR_MASS_G, 1e-6, "which weighs the same way")

local melt = phase_of(contents, "liquid")
assert(melt ~= nil, "the meltwater is a state of its own")
near(melt.mass_g, melt.moles * MOLAR_MASS_G, 1e-6, "and it weighs what it is")

-- Both states together are the lump that was set down, minus what the
-- open glass exhaled: an absolute anchor, so a mass that agreed with
-- its own wrong moles could not pass either.
local weighed = lump.mass_g + melt.mass_g
assert(weighed < LUMP_MOL * MOLAR_MASS_G,
    ("under the 36.03 g that was set down: %g g"):format(weighed))
assert(weighed > LUMP_MOL * MOLAR_MASS_G * 0.95,
    ("and all but a breath of it: %g g"):format(weighed))

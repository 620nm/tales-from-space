-- A canister with WATER in it.
--
-- The bottle is the same noun every gas store on the station uses. It
-- is a shell with a valve on it, and nothing about a shell says gas --
-- so a map that charges one with ten litres of water gets a bottle of
-- water, not a refusal and not a tank of steam
-- (content/blends/water_10l.luau, docs/map-properties/blends.md).
--
-- Four sentences, all of them things a crewman with the panel open
-- could read:
--   * the charge is an AMOUNT: ten litres landed as ten litres of
--     liquid, and the shell is still the 2 000 L it always was
--   * the liquid takes room away from the gas: headspace is the shell
--     less the slug
--   * a shut bottle of water reads NO pressure. There is no gas in it,
--     and a gauge over a slug of water is a gauge over nothing
--   * open the valve and what appears over the slug is VAPOUR, a couple
--     of kPa of it. The water in the bottle is conserved to the mole:
--     the valve moves what fills its container, and a liquid is not
--     that (the engine marks the gap itself)

t.world([==[(
    name: "water bottle",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    blends: {
        // Ten litres, as content/blends/water_10l.luau spells it:
        // 10 000 mL at 1.0 g/mL over 18.015 g/mol.
        "water_10l": (rows: [("water", 555.0929780738273)], temperature_k: 293.15, amount: total),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    structures: [
        (2, 1, "canister", { "blend": "water_10l" }),
    ],
)]==], 0)

local p = t.join()
t.tick()

local CHARGE_MOL = 555.0929780738273
local SHELL_L = 2000.0
local SLUG_L = 10.0

local function near(got, want, tol, what)
    assert(got ~= nil, what .. ": nothing was answered")
    assert(math.abs(got - want) <= tol,
        ("%s: wanted %g, got %g"):format(what, want, got))
end

local can = t.target_at(2, 1, "canister")
local shut = t.vessel(can)
assert(shut ~= nil, "a canister has an inside")

-- ---------------------------------------------------------------
-- What is in it, and how much room is left. A `total` charge is an
-- amount: ten litres is ten litres whatever the shell.
-- ---------------------------------------------------------------
assert(shut.contents.water ~= nil, "the map put water in the bottle")
near(shut.contents.water.liquid, CHARGE_MOL, 1e-6, "ten litres of water, as liquid")
assert(shut.contents.water.gas == nil, "and none of it arrived as steam")
near(shut.volume_l, SHELL_L, 1e-6, "the shell is still the canister's own")
near(shut.headspace_l, SHELL_L - SLUG_L, 0.1,
    "the slug takes its ten litres out of the headspace")

-- ---------------------------------------------------------------
-- A shut bottle of water reads nothing. Pressure is what a gas does
-- to its container and there is no gas in here, so the gauge is
-- honest at zero rather than reporting the water as if it were.
-- ---------------------------------------------------------------
near(shut.pressure_kpa, 0.0, 1e-9, "a slug of water pushes on nothing")
near(t.canister_pressure(2, 1), 0.0, 1e-9, "and the bottle's own gauge agrees")

-- ---------------------------------------------------------------
-- Open the valve. The headspace comes to sit over the water, which
-- means VAPOUR: a couple of kPa of it at room temperature, well
-- under the ten a technician would call a pressure.
-- ---------------------------------------------------------------
t.click(p, 2, 1, can)
t.tick()
local ui = t.ui(p)
assert(ui ~= nil, "clicking a bottle opens its panel")
assert(ui.toggles[1].field == "valve" and ui.toggles[1].on == false,
    "it arrives shut, because a map that said nothing said nothing")
t.ui_act(p, "toggle", '{"field":"valve"}')
t.run_ticks(200)

local open = t.vessel(can)
local w = open.contents.water
assert(w ~= nil, "the water is still in there")
assert(w.gas ~= nil and w.gas > 0.0, "and some of it is standing over itself as vapour")
assert(open.pressure_kpa >= 1.0 and open.pressure_kpa <= 10.0,
    "vapour over water at room temperature, not a pressure: " .. open.pressure_kpa)
near(t.canister_pressure(2, 1), open.pressure_kpa, 1e-6,
    "the gauge on the bottle and the reading in the panel are one number")

-- ---------------------------------------------------------------
-- And NOTHING LEFT. Every mole the map put in this bottle is still
-- in it: some of it moved phase, none of it moved through the
-- valve. A valve releases what fills its container, and the slug on
-- the bottom of the bottle is not that -- which is exactly the gap
-- the engine marks for itself rather than pretending it is closed.
-- ---------------------------------------------------------------
near((w.liquid or 0.0) + (w.gas or 0.0) + (w.solid or 0.0), CHARGE_MOL, 1e-6,
    "the water in the bottle is conserved to the mole")
assert(w.liquid > CHARGE_MOL * 0.99,
    "and virtually all of it is still the slug: " .. w.liquid)

-- A canister with WATER in it.
--
-- The bottle is the same noun every gas store on the station uses. It
-- is a shell with a valve on it, and nothing about a shell says gas --
-- so a map that charges one with ten litres of water and ten
-- atmospheres of air gets exactly that, and not a refusal
-- (content/blends/water_10l.luau, docs/map-properties/blends.md).
--
-- Four sentences, all of them things a crewman with the panel open
-- could read:
--   * the charge is an AMOUNT: ten litres landed as ten litres of
--     liquid, and the shell is still the 2 000 L it always was
--   * the liquid takes room away from the gas: headspace is the shell
--     less the slug
--   * a SHUT bottle of water comes to sit at its own vapour pressure.
--     The headspace saturates whether the valve is open or not, so a
--     couple of kPa of steam stands over the slug and the slug pays
--     the latent heat for it -- the bottle is a degree or two colder
--     than the room it was filled in
--   * put AIR in over the water, wind the regulator up and throw the
--     valve, and the bottle empties itself into the room -- of air. The
--     slug is still there afterwards to a fraction of a percent, and
--     the only water that left went as vapour: a valve moves what fills
--     its container, and a liquid is not that (the engine marks the gap
--     itself)

t.world([==[(
    name: "water bottle",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    blends: {
        // Ten litres, as content/blends/water_10l.luau spells it:
        // 10 000 mL at 1.0 g/mL over 18.015 g/mol -- and ten
        // atmospheres of ordinary 21/79 air standing over it. The air
        // is pV/RT over the HEADSPACE, which is the shell less the
        // slug: 10 * 101 325 Pa * 1.99 m3 / (8.314 * 293.15 K) is
        // 827.31 mol, split 173.74 / 653.58. A bottle with a pressure
        // in it is a bottle whose valve can do something.
        "wet_air": (rows: [
            ("water", 555.0929780738273),
            ("o2", 173.73569857918912),
            ("n2", 653.5771517979019),
        ], temperature_k: 293.15, amount: total),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    structures: [
        (2, 1, "canister", { "blend": "wet_air" }),
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
assert(shut.contents.o2 ~= nil and shut.contents.n2 ~= nil, "with air over it")
near(shut.volume_l, SHELL_L, 1e-6, "the shell is still the canister's own")
near(shut.headspace_l, SHELL_L - SLUG_L, 0.1,
    "the slug takes its ten litres out of the headspace")

-- ---------------------------------------------------------------
-- Leave it standing SHUT. The headspace does not stay dry: the
-- bottle settles on its own cadence whether or not the valve is
-- open, and what a slug of water at room temperature puts into the
-- air over itself is a couple of kPa of steam, alongside the ten
-- atmospheres of air already standing there.
--
-- The slug pays for it in latent heat, so the bottle ends up a
-- couple of degrees under the room it was filled in.
-- ---------------------------------------------------------------
t.run_ticks(200)

local settled = t.vessel(can)
local s = settled.contents.water
assert(s ~= nil, "the water is still in there")
assert(s.gas ~= nil and s.gas > 0.0,
    "a shut bottle of water stands over its own vapour")

-- Water's share of the headspace, said out loud: nRT/V over the room
-- the air left it, which is the partial pressure a technician's
-- analyzer would print beside the air's.
local R = 8.314
local water_kpa = s.gas * R * settled.temp_k / (settled.headspace_l / 1000.0) / 1000.0
assert(water_kpa >= 1.0 and water_kpa <= 10.0,
    "vapour pressure, not a pressure: " .. water_kpa)
near(t.canister_pressure(2, 1), settled.pressure_kpa, 1e-6,
    "the gauge on the bottle and the reading in the panel are one number")
assert(settled.temp_k < 293.15,
    "boiling off the vapour cost the slug its heat: " .. settled.temp_k)
near((s.liquid or 0.0) + (s.gas or 0.0) + (s.solid or 0.0), CHARGE_MOL, 1e-6,
    "and nothing was made or lost getting there")

-- ---------------------------------------------------------------
-- Now make the valve DO something. The bottle stands loose on the
-- deck, so its valve is pointed at the room; wind the regulator up
-- past what the room already holds and the bottle has ten
-- atmospheres to push with and somewhere to push it.
-- ---------------------------------------------------------------
local air_before = settled.contents.o2.gas + settled.contents.n2.gas
local water_before = (s.liquid or 0.0) + (s.gas or 0.0)
local room_before = t.room_pressure(3, 1)

t.click(p, 2, 1, can)
t.tick()
local ui = t.ui(p)
assert(ui ~= nil, "clicking a bottle opens its panel")
assert(ui.toggles[1].field == "valve" and ui.toggles[1].on == false,
    "it arrives shut, because a map that said nothing said nothing")
t.ui_act(p, "set", '{"field":"release","value":400}')
t.ui_act(p, "toggle", '{"field":"valve"}')
t.run_ticks(200)

-- ---------------------------------------------------------------
-- The air went. The water stayed. Nearly half the air in the
-- bottle is in the room now and the room says so on its own gauge
-- -- and the slug on the bottom lost a fifth of one percent of
-- itself, all of it as vapour riding out with the air.
--
-- A valve releases what FILLS ITS CONTAINER. A liquid does not, so
-- ten litres of water cannot leave a canister however wide the
-- valve is opened -- which is exactly the gap the engine marks for
-- itself rather than pretending it is closed.
-- ---------------------------------------------------------------
local open = t.vessel(can)
local w = open.contents.water
assert(w ~= nil, "the water did not leave through the valve")

local air_after = open.contents.o2.gas + open.contents.n2.gas
assert(air_after < air_before * 0.7,
    ("the air emptied into the room: %g -> %g"):format(air_before, air_after))
assert(t.room_pressure(3, 1) > room_before + 100.0,
    "and the room's own gauge went up with it: " .. t.room_pressure(3, 1))

local water_after = (w.liquid or 0.0) + (w.gas or 0.0)
assert(water_after > water_before * 0.99,
    ("while the water hardly moved: %g -> %g"):format(water_before, water_after))
assert(w.liquid > CHARGE_MOL * 0.99,
    "and the slug is still the slug: " .. w.liquid)
assert(water_before - water_after < (w.gas or 0.0) * 2.0,
    "what left it was vapour, and not much more than a headspace of that")

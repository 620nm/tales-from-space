-- THE MEDICINE TRUNK, end to end: an empty beaker, an empty bottle,
-- and a shelf of buttons, and at the far end a crewman whose bruises
-- stop hurting.
--
-- Nothing here is set up. Every mole came out of the dispenser through
-- a button somebody pressed, every reaction ran because the substances
-- were in the same vessel at the same temperature, and the only two
-- machines involved are the two a chemistry bench has.
--
-- The chain is four rungs and each one teaches the rung above it:
--
--   welding fuel + carbon        -> oil          an open beaker
--   water + chlorine + oil       -> phenol       a bottle, because Cl2
--   phenol + saltpetre           -> libital      the reaction chamber
--   ash + salt                   -> multiver     a NARROW window
--
-- ...and then somebody drinks it.
--
-- WHY THE BOTTLE, said once. There is one id per molecule (D3,
-- docs/CHEMISTRY.md 7): `chlorine` is Cl2, which boils at 239 K, so a
-- press of it over an open beaker is refused -- what landed would leave
-- through the same mouth before the chemist looked up. Pressed into a
-- vessel with a stopper in it the identical press lands and condenses
-- under its own vapour pressure, and LIQUID chlorine is what phenol's
-- recipe names. The stopper is not a convenience; it is the second
-- lesson of the bench, after salt taught the first
-- (tests/chem_bench_test.luau).
--
-- WHAT FITS, and why every quantity here is small. Capacity is geometry
-- (D2) and geometry caps a reaction by the FREE SHELL VOLUME (D16), so
-- a recipe whose products take more room than its reactants stops when
-- the glass is full rather than growing it. Three libital at 180 mL a
-- mole come out of 136 mL of legs, so a whole extent swells the
-- contents by 404 mL against a fifty-millilitre bottle: a tenth of an
-- extent is what this vessel can actually make, and the presses below
-- are half of that again so the assertion is about the CLAMP and never
-- about the shell.
local NOZZLE_K = 300.0
-- A twentieth of a press. One tg unit is 0.025 mol (docs/CHEMISTRY.md
-- 4), so this is two units a leg -- small, because the products are
-- bulky and because the point is the chain rather than the yield.
local LEG = 0.05
-- Chlorine goes in at twice the recipe's share. Not greed: a saturated
-- headspace keeps some of it as VAPOUR whatever the vessel holds
-- (about 0.017 mol at 303 K in this bottle), and a rule naming the
-- liquid cannot reach that. Twice the share means the liquid outlasts
-- the water and the oil, so the run ends on stoichiometry rather than
-- on saturation -- which is the lesson chem_bench_test already taught
-- and this spec does not need to repeat.
local CHLORINE = 0.10

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function amount(handle, key)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    return contents[key] or 0
end

-- ---------------------------------------------------------------
-- THE BENCH. A dispenser, a reaction chamber, a generator to take the
-- heat this shift makes, and four pieces of glass.
-- ---------------------------------------------------------------
t.world([==[(
    name: "medicine bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#.g.#",
        "#o..#",
        "#a..#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [
        (1, 2, "beaker"),
        (3, 2, "bottle"),
        (3, 3, "beaker"),
        (2, 3, "beaker.libital"),
    ],
    machines: [(1, 1, "chem_dispenser"), (3, 1, "chem_heater")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3),
        (1, 3, 3), (2, 3, 3), (3, 3, 3),
    ],
)]==], 0)

local p = t.join()
t.tick()

local dispenser = t.target_at(1, 1)
local heater = t.target_at(3, 1)
local a = t.target_at(1, 2, "beaker")
local jar = t.target_at(3, 2, "bottle")
local b = t.target_at(3, 3, "beaker")
local med = t.target_at(2, 3, "beaker.libital")

-- The crewman stands in the middle of the bench, so both machines and
-- all four vessels are within arm's reach and this spec is never about
-- walking. Everything they put down lands on their own feet, and
-- everything they pick up again is named by the handle rather than by
-- the tile.
local function take(handle, x, y)
    t.click(p, x, y, handle)
    t.tick()
end

local function dock(machine, x, y)
    t.click(p, x, y, machine)
    t.tick()
    assert(t.hands(p).held == nil, "the vessel went into the machine")
end

local function panel(machine, x, y)
    t.click(p, x, y, machine)
    t.tick()
end

local function press(key)
    t.ui_act(p, "toggle", '{"field":"dispense","option":"' .. key .. '"}')
    t.run_ticks(2)
end

local function dial_to(moles)
    t.ui_act(p, "set", '{"field":"amount","value":' .. moles .. '}')
    t.run_ticks(2)
end

local function eject()
    t.ui_act(p, "toggle", '{"field":"eject"}')
    t.run_ticks(2)
end

local function put_down()
    t.drop(p)
    t.tick()
end

-- ---------------------------------------------------------------
-- ONE: OIL, WHICH IS THE ONLY RUNG A BEAKER CAN DO.
--
-- tg: 1 welding fuel + 1 carbon + 1 hydrogen -> 3 oil
-- (recipes/others.dm:579-582) without its hydrogen, which is H2 here
-- and therefore not something an open vessel holds
-- (reactions/oil.luau). Two buttons, on the shared mixing bell, at
-- room temperature.
-- ---------------------------------------------------------------
take(a, 1, 2)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
dial_to(LEG / 2)
press("welding_fuel")
press("carbon")
t.run_seconds(20)
near(amount(a, "oil"), LEG, 1e-6, "two of oil for one of each leg")
near(amount(a, "welding_fuel"), 0.0, 1e-6, "and both legs are spent")
eject()
put_down()

-- ---------------------------------------------------------------
-- TWO: AND THEN THE BOTTLE, WHICH IS THE RUNG NOTHING ELSE CAN DO.
--
-- The press lands as gas and the bottle's own sweep condenses it back
-- to the eight atmospheres its saturation line allows. Condensing is
-- ADIABATIC, so 20.4 kJ of latent heat a mole lands in a mixture whose
-- whole capacity is three joules a kelvin and the bottle gets HOT --
-- which is why it goes on the deck afterwards and the water waits.
-- ---------------------------------------------------------------
take(jar, 3, 2)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
dial_to(CHLORINE)
press("chlorine")
t.run_seconds(10)
near(amount(jar, "chlorine"), CHLORINE, 1e-9, "the whole press landed, because there is a lid")
assert(t.holder_k(jar) > NOZZLE_K + 40.0,
    "and the latent heat is where the temperature went: " .. t.holder_k(jar))

-- A container LYING ON THE DECK trades heat with its tile every atmos
-- pass (sim/holder/heat.rs); a docked or carried one is insulated.
eject()
put_down()
t.run_seconds(600)
local cooled = t.vessel(jar)
assert(cooled.temp_k < 320.0, "the deck took the heat back: " .. cooled.temp_k)
assert((cooled.contents.chlorine.liquid or 0) > 0.5 * CHLORINE,
    "and most of it is standing as LIQUID chlorine: " .. tostring(cooled.contents.chlorine.liquid))

-- ---------------------------------------------------------------
-- THREE: PHENOL. Three legs, and one of them is a phase.
--
-- tg: 1 water + 1 chlorine + 1 oil -> 3 phenol, thermic_constant 50
-- (recipes/others.dm:584-588). The oil is poured in off the beaker,
-- because a pour asks nothing about the lid; the water is pressed in
-- after it, because the reaction should start with everything at the
-- deck's temperature rather than chasing the nozzle.
-- ---------------------------------------------------------------
take(a, 2, 2)
t.click(p, 2, 2, jar)
t.tick()
near(amount(jar, "oil"), LEG, 1e-9, "the oil went into the bottle")
near(amount(a, "oil"), 0.0, 1e-9, "and the beaker is empty")
put_down()

take(jar, 2, 2)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
dial_to(LEG)
press("water")
eject()
put_down()

-- On the deck, so the exotherm has somewhere to go and the chlorine
-- stays where a rule can read it. Three minutes: a rate that reads
-- concentration is a decay, and the last thousandth takes as long again
-- as the first nine tenths (docs/CHEMISTRY.md 5).
t.run_seconds(180)
near(amount(jar, "phenol"), 3.0 * LEG, 1e-4, "three of phenol for one of each leg")
near(amount(jar, "oil"), 0.0, 1e-4, "and the oil is gone")
near(amount(jar, "water"), 0.0, 1e-4, "and so is the water")
-- The chlorine that is LEFT is the reason the press was doubled: the
-- run ended on the two legs it was meant to end on.
assert(amount(jar, "chlorine") > 0.0, "with chlorine to spare, which is the point of the excess")

-- ---------------------------------------------------------------
-- FOUR: LIBITAL, WHICH IS WHAT THE REACTION CHAMBER IS FOR.
--
-- tg: 1 phenol + 1 oxygen + 1 nitrogen -> 3 libital, required_temp 225,
-- optimal_temp 700 (recipes/cat2_medicines.dm:51-68). Both gas legs
-- became one solid here -- saltpetre is KNO3 and carries the nitrogen
-- and the oxygen in a button that already exists
-- (reactions/libital.luau).
--
-- The window is the whole gesture. At the deck's temperature the bell
-- is about four hundredths, so a bottle standing about makes libital
-- at a twenty-fifth of the rate the chamber does: it is not GATED, it
-- is slow, and the machine is what turns an afternoon into two minutes.
-- ---------------------------------------------------------------
take(jar, 2, 2)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
dial_to(LEG)
press("saltpetre")
near(amount(jar, "saltpetre"), LEG, 1e-9, "a press of saltpetre")
eject()

dock(heater, 3, 1)
panel(heater, 3, 1)
t.ui_act(p, "set", '{"field":"temperature","value":800}')
t.ui_act(p, "toggle", '{"field":"power"}')

-- Two minutes of sim time, heating included. The thermostat closes a
-- twentieth of its gap every atmos pass, so the plateau arrives inside
-- half a minute and the rest is the reaction.
t.run_seconds(120)
assert(t.holder_k(jar) > 690.0, "the chamber reached the plateau: " .. t.holder_k(jar))
near(amount(jar, "libital"), 3.0 * LEG, 1e-4, "three of libital for one of saltpetre")
near(amount(jar, "saltpetre"), 0.0, 1e-4, "which spent every mole of it")
near(amount(jar, "phenol"), 2.0 * LEG, 1e-4, "and two thirds of the phenol is still standing")

t.ui_act(p, "toggle", '{"field":"power"}')
eject()
put_down()

-- ---------------------------------------------------------------
-- FIVE: MULTIVER, AND A WINDOW WITH A CEILING ON IT.
--
-- tg: 1 ash + 1 salt -> 2 multiver, required_temp 380, optimal_temp
-- 400, overheat_temp 410 (recipes/cat2_medicines.dm:266-282). No
-- departure at all -- both legs are on the shelf and the ratio is tg's.
--
-- Thirty kelvin wide. `BellCurve` is exactly ZERO outside its ends
-- (docs/CHEMISTRY.md 7), so this is the one recipe on the bench where a
-- chemist who dials the chamber to its stop gets a hot beaker and
-- nothing in it -- and where ten kelvin short of the floor is not
-- "slower", it is nothing.
-- ---------------------------------------------------------------
take(b, 3, 3)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
dial_to(LEG)
press("ash")
press("salt")
near(amount(b, "ash"), LEG, 1e-9, "a press of ash")
near(amount(b, "salt"), LEG, 1e-9, "and a press of salt")
eject()

dock(heater, 3, 1)
panel(heater, 3, 1)
t.ui_act(p, "set", '{"field":"temperature","value":370}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_seconds(120)

-- The thermostat approaches its setpoint asymptotically and never
-- crosses it (sim/virtual_bath.rs), so 370 on the dial is a beaker that
-- is genuinely under the floor.
local warm = t.holder_k(b)
assert(warm > 360.0 and warm < 380.0, "the chamber is ten kelvin short: " .. warm)
near(amount(b, "multiver"), 0.0, 1e-12, "and ten kelvin short is nothing at all")
near(amount(b, "ash"), LEG, 1e-9, "with every mole of ash still standing")

-- ...and then thirty more on the dial.
t.ui_act(p, "set", '{"field":"temperature","value":400}')
t.run_seconds(120)
assert(t.holder_k(b) > 385.0, "the chamber crossed the floor: " .. t.holder_k(b))
near(amount(b, "multiver"), 2.0 * LEG, 1e-4, "two of multiver for one of each leg")
near(amount(b, "ash"), 0.0, 1e-4, "which spent all the ash")
near(amount(b, "salt"), 0.0, 1e-4, "and all the salt")

t.ui_act(p, "toggle", '{"field":"power"}')
eject()
put_down()

-- ---------------------------------------------------------------
-- SIX: AND SOMEBODY DRINKS IT.
--
-- The far end of the trunk is a bloodstream, which is a vessel like
-- any other (docs/CHEMISTRY.md 1). A swig off a beaker is 0.05 mol of
-- what the beaker HOLDS -- the gesture moves solution, not solute --
-- and a medic's beaker is 0.20 water and 0.15 libital, so what crosses
-- is three sevenths of the swig.
--
-- What is asserted is the HOOK'S RATE. Libital's `mob.life` heals 1.5
-- brute every metabolism tick for as long as there is any of it left,
-- and the metabolism burns `metabolism_rate = 0.003` mol a tick
-- (substances/libital.luau), so the dose decides how many ticks and the
-- hook decides what each one is worth. The dead giveaway that it is
-- the reagent doing it and not the body: when the libital runs out, the
-- healing stops dead.
-- ---------------------------------------------------------------
t.set_health(p, { brute = 30.0 })
t.tick()
near(t.health(p).brute, 30.0, 1e-3, "a crewman with bruises")

take(med, 2, 3)
t.click(p, 2, 2)
t.tick()
local dose = t.blood(p).libital or 0
assert(dose > 0.015, "the swig reached the bloodstream: " .. dose .. " mol")
local hurt = t.health(p).brute

-- One tick per 0.003 mol, and the last partial mouthful still fires the
-- hook -- the metabolism takes `min(present, rate)` and calls it
-- (docs/BENCH.md 1).
local ticks = math.ceil(dose / 0.003)
t.run_seconds(60)
near(t.blood(p).libital or 0, 0.0, 1e-9, "the dose is spent")
near(hurt - t.health(p).brute, ticks * 1.5, 1.6,
    "and it healed 1.5 a tick while it lasted, " .. ticks .. " times over")

-- ...and then it stops, because there is nothing left to burn.
local settled = t.health(p).brute
t.run_seconds(60)
near(t.health(p).brute, settled, 1e-3, "an empty bloodstream heals nobody")
put_down()

-- ---------------------------------------------------------------
-- SEVEN: AIURI, THE ONE THAT MAKES COLD.
--
-- tg: 1 ammonia + 1 sulphuric acid + 2 hydrogen -> 4 aiuri,
-- required_temp 50, optimal_temp 300, overheat_temp 315,
-- thermic_constant -400 (recipes/cat2_medicines.dm:110-126). The
-- hydrogen legs are gone and the count fell with them
-- (reactions/aiuri.luau); the ammonia leg names its LIQUID, so this is
-- bottle work for the same reason phenol was.
--
-- tg's `thermic_constant` is a temperature delta and its sign is the
-- direction: -400 is heat LEAVING the vessel (docs/CHEMISTRY.md 6, + is
-- exothermic). Sixty kilojoules an extent out of a mixture whose whole
-- capacity is eleven joules a kelvin, and the bottle walks itself down
-- out of its own window and stops. Aiuri is the one recipe here that a
-- chemist has to keep WARM.
--
-- A fresh bench, because this one wants a clean bottle and the first
-- one is full of medicine.
-- ---------------------------------------------------------------
t.world([==[(
    name: "cold bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#.g.#",
        "#o..#",
        "#a..#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [(3, 2, "bottle")],
    machines: [(1, 1, "chem_dispenser"), (3, 1, "chem_heater")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3),
        (1, 3, 3), (2, 3, 3), (3, 3, 3),
    ],
)]==], 0)

p = t.join()
t.tick()

dispenser = t.target_at(1, 1)
heater = t.target_at(3, 1)
local flask = t.target_at(3, 2, "bottle")

-- Ammonia first, and the same wait the chlorine needed: a condensable
-- gas pressed into a sealed vessel arrives with its latent heat still
-- in it.
take(flask, 3, 2)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
dial_to(LEG)
press("ammonia")
t.run_seconds(10)
near(amount(flask, "ammonia"), LEG, 1e-9, "the whole press landed, because there is a lid")
eject()
put_down()
t.run_seconds(600)
local settled_k = t.holder_k(flask)
assert(settled_k < 320.0, "the deck took the condensation heat back: " .. settled_k)
assert((t.vessel(flask).contents.ammonia.liquid or 0) > 0.0,
    "and there is LIQUID ammonia standing in it")

-- ...and then the acid, which is a button of its own now
-- (machines/chem_dispenser.luau).
take(flask, 2, 2)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
dial_to(LEG)
press("sulfuric_acid")
near(amount(flask, "sulfuric_acid"), LEG, 1e-9, "a press of sulphuric acid")

-- Six seconds is three holder steps, in a DOCKED vessel, which is
-- insulated from the deck (sim/holder/heat.rs). Nothing warms this but
-- the reaction, and the reaction is the thing taking heat out.
t.run_seconds(6)
assert(amount(flask, "aiuri") > 0.0, "it started: " .. amount(flask, "aiuri") .. " mol")
assert(t.holder_k(flask) < settled_k - 100.0,
    "and it froze itself doing it: " .. t.holder_k(flask) .. " K, from " .. settled_k)

-- Which is exactly why it goes on the hotplate. The chamber pushes back
-- against the endotherm every pass, and what stalled finishes.
eject()
dock(heater, 3, 1)
panel(heater, 3, 1)
t.ui_act(p, "set", '{"field":"temperature","value":320}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_seconds(600)
assert(amount(flask, "aiuri") > 1.5 * LEG,
    "and the chamber saw it through: " .. amount(flask, "aiuri") .. " mol")
assert(amount(flask, "sulfuric_acid") < 0.2 * LEG,
    "spending nearly all the acid: " .. amount(flask, "sulfuric_acid"))

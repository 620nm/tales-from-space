-- A bottle of homebrew, and the lid that makes it one.
--
-- Sugar in water ferments at room temperature (reactions/fermentation.
-- luau), and two of the three moles it makes are CO2 in the gas phase.
-- In an open beaker that gas is gone by the next atmos pass -- an open
-- vessel trades its whole headspace with the room (sim/holder/
-- vent.rs) -- so nothing ever builds up in one. A bottle is corked
-- (items/bottle.luau, `sealed`), and a corked vessel is the only one on
-- this station that can hold a pressure of its own: what ferments in it
-- stays in it, presses on the glass, and says so when you look at it.
--
-- Both halves are here because either alone would pass for the wrong
-- reason. A rising pressure with no open twin could be a bottle that
-- simply reacts faster; a room that gathers CO2 with no bottle beside
-- it could be a lid that leaks slowly. Same brew, same bench, same
-- number of seconds: one vessel keeps it and one gives it away.
--
-- Nothing here is staged. Every mole came out of a button on the
-- dispenser, and the only other thing a crewman did was tip a beaker.

-- THE ARITHMETIC, all of it, before anything is asserted.
--
-- One tg unit is 0.025 mol (docs/CHEMISTRY.md), and the dispenser's
-- dial counts in moles: 0.225 of water (9 u) and 0.025 of sugar (1 u)
-- make one beaker gesture's worth, 0.25 mol = 10 u, which is exactly
-- what one tip of the beaker moves. The mixing glass is left dry, which
-- matters: an open beaker with brew in it would be a second CO2 source
-- in the room while the bottle is being watched.
--
-- Every vessel on the station takes one chemistry step every
-- METABOLISM_EVERY = 40 ticks at 20 Hz, so a step is 2 s (sim/life.rs).
-- Fermentation's bell is flat between 293 and 303 K and the nozzle
-- pours at 300 K, so the rate is its full `base_rate` and each step is
--
--     extent  = 0.002              (base_rate x bell factor 1.0)
--     co2     = 2.0 x 0.002        = 0.004 mol of gas per step
--     sugar   = 1.0 x 0.002        = 0.002 mol per step
--
-- so the sugar buys 0.025 / 1.0 / 0.002 = 12.5 steps, and the whole
-- brew is worth 2 x 0.025 = 0.05 mol of CO2 over about 25 seconds.
--
-- The bottle is 50 mL of glass (`volume_ml`) and the brew displaces
-- what its densities say it does: water 0.225 mol x 18.015 g/mol at
-- 1 g/mL = 4.05 mL, sugar 0.025 mol x 342.3 g/mol at the unauthored
-- default 1 g/mL = 8.56 mL. That leaves a headspace of
--
--     50 - 4.05 - 8.56 = 37.4 mL = 3.74e-5 m^3
--
-- and the ideal gas law over it says how much gas a warning costs:
--
--     n = pV/RT = 150000 x 3.74e-5 / (8.314 x 300) = 0.00225 mol
--
-- which is less than the 0.004 mol ONE step makes. So the bottle is
-- over `STRAINING_KPA` after the very first step of fermentation, at
-- roughly 0.004 x 8.314 x 300 / 3.78e-5 = 264 kPa, and climbs by about
-- that much again every two seconds until the sugar runs out.
local U = 0.025
local WATER = 9 * U
local SUGAR = 1 * U
local STEP_CO2 = 0.004
local STRAIN = 150.0 -- lunatic_core::STRAINING_KPA
local STEPS = 10 -- watched steps, inside the sugar's 12.5

local function near(got, want, slack, what)
    assert(got ~= nil, what .. ": nothing was answered")
    assert(
        math.abs(got - want) < slack,
        ("%s: wanted %g, got %g"):format(what, want, got)
    )
end

local function says(look, needle)
    assert(look ~= nil, "the look was refused")
    for _, line in ipairs(look.lines) do
        if line:find(needle, 1, true) ~= nil then
            return true
        end
    end
    return false
end

t.world([==[(
    name: "ferment bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'g': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
    },
    rows: [
        "#####",
        "#o.a#",
        "#g..#",
        "#####",
    ],
    spawns: [(2, 1)],
    items: [(1, 1, "beaker"), (3, 1, "bottle"), (3, 2, "beaker")],
    machines: [(2, 2, "chem_dispenser")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3),
    ],
)]==], 0)

local p = t.join()
t.tick()

local taps = t.target_at(2, 2)
local mixer = t.target_at(1, 1, "beaker")
local bottle = t.target_at(3, 1, "bottle")
local twin = t.target_at(3, 2, "beaker")

-- The whole room's CO2, over every tile of it. A sealed room with no
-- vents in it has nowhere else to put gas, so this is the honest test
-- of "did any of it get out".
local function room_co2()
    local n = 0
    for x = 1, 3 do
        for y = 1, 2 do
            local gases = t.room_gas(x, y)
            n = n + ((gases and gases.co2) or 0)
        end
    end
    return n
end

local function co2_in(vessel)
    local reading = t.vessel(vessel)
    assert(reading ~= nil, "that is a vessel")
    local entry = reading.contents.co2
    return entry and (entry.gas or 0) or 0
end

local function open_panel()
    t.click(p, 2, 2, taps)
    t.tick()
end

local function dial(moles)
    t.ui_act(p, "set", '{"field":"amount","value":' .. moles .. '}')
    t.run_ticks(2)
end

local function press(key)
    t.ui_act(p, "toggle", '{"field":"dispense","option":"' .. key .. '"}')
    t.run_ticks(2)
end

-- Nine units of water and one of sugar into the mixing glass, then out
-- of the machine and into whatever is being filled this time.
local function brew_into(x, y, vessel)
    t.click(p, 2, 2, taps)
    t.tick()
    assert(t.hands(p).held == nil, "the mixing beaker is in the dispenser")
    open_panel()
    dial(WATER)
    press("water")
    dial(SUGAR)
    press("sugar")
    t.ui_act(p, "toggle", '{"field":"eject"}')
    t.run_ticks(2)
    assert(t.hands(p).held == "beaker", "and it comes back out")
    t.click(p, x, y, vessel)
    t.tick()
    -- ...all of it but the whisker of vapour standing over the liquid:
    -- a pour moves the LIQUID phase, and the mixing beaker is open, so
    -- what its own surface has evaporated into its headspace stays
    -- behind (docs/MATTER.md 5).
    near(t.vessel(mixer).moles, 0, 1e-4, "one gesture is the whole 10 u")
end

-- ---------------------------------------------------------------
-- ONE: THE BOTTLE.
-- ---------------------------------------------------------------
t.click(p, 1, 1, mixer)
t.tick()
brew_into(3, 1, bottle)

local started = t.vessel(bottle)
assert(started.sealed, "a bottle has a stopper in it")
-- A tenth of a millimole of slack, for the vapour the mixing beaker
-- kept: a pour moves the liquid, and an open glass always has a little
-- of itself standing over it as gas.
near(started.moles, WATER + SUGAR, 2e-4, "a quarter of a mole of brew went in")
near(started.contents.water.liquid, WATER, 2e-4, "nine units of water")
near(started.contents.sugar.liquid, SUGAR, 1e-9, "and one of sugar")
near(started.temp_k, 300.0, 0.5, "at the nozzle's temperature, on the bell's plateau")
near(started.volume_l, 0.05, 1e-9, "fifty millilitres of glass")
near(started.headspace_l, 0.05 - 0.00405 - 0.00856, 1e-4, "and 37 mL of room over it")
near(started.pressure_kpa, 0, 1e-9, "nothing pressing on the cork yet")
assert(
    not says(t.examine(p, 3, 1, bottle), "strains"),
    "and nothing to say about a lid"
)

-- Ten steps of two seconds, watched one at a time: the gas is made
-- inside the glass and has nowhere to go.
local last_co2, last_kpa = 0, 0
for step = 1, STEPS do
    t.run_seconds(2)
    local reading = t.vessel(bottle)
    local co2 = co2_in(bottle)
    near(co2, step * STEP_CO2, 1e-9, ("step %d makes its 0.004 mol"):format(step))
    assert(
        co2 > last_co2,
        ("the CO2 grows every step: %g then %g"):format(last_co2, co2)
    )
    assert(
        reading.pressure_kpa > last_kpa,
        ("and so does the gauge: %g then %g"):format(last_kpa, reading.pressure_kpa)
    )
    near(room_co2(), 0, 1e-12, ("nothing reached the room on step %d"):format(step))
    last_co2, last_kpa = co2, reading.pressure_kpa
    -- One step's gas is already past the warning, by the arithmetic at
    -- the top of this file -- so the sentence is there from the first
    -- sample onward and never goes away while the sugar lasts.
    assert(
        reading.pressure_kpa > STRAIN,
        ("over the strain by step %d: %g kPa"):format(step, reading.pressure_kpa)
    )
    assert(
        says(t.examine(p, 3, 1, bottle), "It strains against its lid."),
        ("and the bottle says so on step %d"):format(step)
    )
end

near(last_co2, STEPS * STEP_CO2, 1e-9, "ten steps of fermentation, all of it kept")
assert(last_kpa > 2000.0, "a bottle under real pressure: " .. last_kpa)
-- The brew is a brew, not just a gas source: what the sugar became is
-- in there too, two of ethanol for every one of it. Counted over BOTH
-- phases, because ethanol has a real vapour curve (substances/
-- ethanol.luau) and a trace of it is standing in the headspace with
-- the CO2 -- which is also part of what the gauge is reading.
local spirit = t.vessel(bottle).contents.ethanol
near(
    spirit.liquid + (spirit.gas or 0),
    last_co2,
    1e-9,
    "as much ethanol as carbon dioxide, which is the recipe"
)
assert(spirit.gas > 0, "and some of it is vapour: " .. spirit.gas)

-- ---------------------------------------------------------------
-- TWO: THE SAME BREW, IN AN OPEN GLASS.
--
-- Nine units of water and one of sugar again, off the same taps into
-- the beaker standing on the deck. Everything about it is the bottle's
-- twin except the cork, so the CO2 has one difference to answer to.
-- ---------------------------------------------------------------
brew_into(3, 2, twin)

local twin_start = t.vessel(twin)
assert(not twin_start.sealed, "a beaker has no lid to strain against")
near(twin_start.moles, WATER + SUGAR, 2e-4, "the same quarter of a mole")
near(twin_start.contents.sugar.liquid, SUGAR, 1e-9, "and the same unit of sugar")
near(room_co2(), 0, 1e-12, "the room is still clean when it starts")

for step = 1, STEPS do
    t.run_seconds(2)
    near(
        room_co2(),
        step * STEP_CO2,
        1e-9,
        ("the room took step %d's whole 0.004 mol"):format(step)
    )
    near(co2_in(twin), 0, 1e-9, "and the glass kept none of it")
    local reading = t.vessel(twin)
    assert(
        reading.pressure_kpa < STRAIN,
        "an open glass never builds a pressure: " .. reading.pressure_kpa
    )
end

assert(
    not says(t.examine(p, 3, 2, twin), "strains"),
    "so it has nothing to say about a lid it does not have"
)
near(room_co2(), STEPS * STEP_CO2, 1e-9, "ten steps of it, all of it breathed out")
-- And the lid held throughout. The bottle went on fermenting while the
-- beaker did -- its unit of sugar is worth 12.5 steps and only ten were
-- watched -- so it is now holding the whole 2 x 0.025 mol its brew was
-- worth, and not one mole of that is in the air of this room.
near(co2_in(bottle), 2 * SUGAR, 1e-9, "the bottle kept everything its sugar made")
assert(
    co2_in(bottle) > room_co2(),
    "and it is still holding more than the room ever gathered"
)
assert(
    says(t.examine(p, 3, 1, bottle), "It strains against its lid."),
    "still straining, with the room around it at a comfortable pressure"
)

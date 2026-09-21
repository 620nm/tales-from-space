local ui_controls = require("@helpers/ui_controls")

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
-- pours at 300 K, so the bell factor is 1 and the rate is `base_rate`
-- times the ACTIVITY of the scarcest reactant (docs/CHEMISTRY.md 5).
--
-- The brew displaces what its densities say it does: water
-- 0.225 mol x 18.015 g/mol at 1.0 g/mL = 4.053 mL, sugar 0.025 mol x
-- 342.3 g/mol at sucrose's 1.59 g/mL = 5.382 mL. So the SOLUTION is
-- 9.435 mL, the sugar in it is 0.025 / 0.009435 L = 2.650 M against
-- water's 23.85 M, and the first step is
--
--     extent  = 0.00025 x 2.650      = 6.624e-4
--     co2     = 2.0 x extent         = 1.3248e-3 mol of gas
--     sugar   = 1.0 x extent         = 6.624e-4 mol spent
--
-- Every step after it is a shade smaller, because the sugar it reads is
-- a shade thinner: a rate that reads concentration is a DECAY and not a
-- march, and the brew tails off rather than stopping dead. Ten steps
-- make 12.11 mmol of CO2, not ten equal helpings of the first -- a
-- shade over the 12.106 that arithmetic on the fills alone gives,
-- because water has a curve and a little of it stands in the headspace
-- as vapour, which makes the solution it left a little thinner and the
-- sugar in it a little stronger.
--
-- The bottle is 50 mL of glass (`volume_ml`), leaving a headspace of
--
--     50 - 4.053 - 5.382 = 40.56 mL = 4.056e-5 m^3
--
-- and the ideal gas law over it says how much gas a warning costs:
--
--     n = pV/RT = 150000 x 4.056e-5 / (8.314 x 300) = 0.00244 mol
--
-- which is two steps' worth. So the bottle crosses `STRAINING_KPA` on
-- step two and never comes back under it.
--
-- CO2 has a phase diagram of its own now, and this bottle never
-- reaches it: carbon dioxide condenses at 6.3 MPa at 300 K, which is
-- forty times what a straining bottle is at. What is made here is gas
-- and stays gas.
-- NOBODY IN HERE IS BREATHING. A crewman with lungs is a chemical
-- plant standing in the room: his lungs are a driven vessel that holds
-- several litres of the air inside itself and turns what it takes in
-- into something else (docs/BIOLOGY.md, `sim/holder/bellows.rs`). That
-- is a source and a sink, and the books below are the ATMOSPHERICS
-- engine's -- so the crew are switched off as scaffolding, the same
-- standing `t.set_health` has.
t.set_breathing(false)

local U = 0.025
local WATER = 9 * U
local SUGAR = 1 * U
local FIRST_CO2 = 0.0013248 -- 2 x 0.00025 x 2.650 M
local TEN_STEPS_CO2 = 0.0121108 -- the decay's sum, not 10 x the first
local STRAIN = 150.0 -- lunatic_core::STRAINING_KPA
local STRAIN_STEP = 2 -- where 0.00244 mol of headspace is bought
local STEPS = 10 -- watched steps, with sugar to spare

local function near(got: number?, want: number, slack: number, what: string)
    assert(got ~= nil, what .. ": nothing was answered")
    assert(math.abs(got - want) < slack, ("%s: wanted %g, got %g"):format(what, want, got))
end

local function says(look: SpecExamine?, needle: string)
    assert(look ~= nil, "the look was refused")
    for _, line in ipairs(look.lines) do
        if line:find(needle, 1, true) ~= nil then
            return true
        end
    end
    return false
end

t.world(
    [==[(
    name: "ferment bench",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    rows: [
        "#####",
        "#o.a#",
        "#g..#",
        "#####",
    ],
    structures: [(2, 1, "player_spawn"), (3, 1, "apc")],
    items: [(1, 1, "beaker"), (3, 1, "bottle"), (3, 2, "beaker")],
    machines: [(2, 2, "chem_dispenser")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
    ],
)]==],
    0
)

local p = t.join()
t.tick()

local taps = assert(t.target_at(p, 2, 2))
local mixer = assert(t.target_at(p, 1, 1, "beaker"))
local bottle = assert(t.target_at(p, 3, 1, "bottle"))
local twin = assert(t.target_at(p, 3, 2, "beaker"))

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
    local reading = assert(t.vessel(vessel), "that is a vessel")
    local entry = reading.contents.co2
    return entry and (entry.gas or 0) or 0
end

local function open_panel()
    t.click(p, 2, 2, taps)
    t.tick()
end

local function dial(moles)
    ui_controls.set(p, "amount", moles)
    t.run_ticks(2)
end

local function press(key)
    ui_controls.toggle(p, "dispense", key)
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
    ui_controls.toggle(p, "eject")
    t.run_ticks(2)
    assert(t.hands(p).held == "beaker", "and it comes back out")
    t.click(p, x, y, vessel)
    t.tick()
    -- ...all of it but the whisker of vapour standing over the liquid:
    -- a pour moves the LIQUID phase, and the mixing beaker is open, so
    -- what its own surface has evaporated into its headspace stays
    -- behind (docs/MATTER.md 5).
    near(assert(t.vessel(mixer)).moles, 0, 1e-4, "one gesture is the whole 10 u")
end

-- ---------------------------------------------------------------
-- ONE: THE BOTTLE.
-- ---------------------------------------------------------------
t.click(p, 1, 1, mixer)
t.tick()
brew_into(3, 1, bottle)

local started = assert(t.vessel(bottle))
assert(started.sealed, "a bottle has a stopper in it")
-- A tenth of a millimole of slack, for the vapour the mixing beaker
-- kept: a pour moves the liquid, and an open glass always has a little
-- of itself standing over it as gas.
near(started.moles, WATER + SUGAR, 2e-4, "a quarter of a mole of brew went in")
near(started.contents.water.liquid, WATER, 2e-4, "nine units of water")
near(started.contents.sugar.solid, SUGAR, 1e-9, "and one of sugar")
near(started.temp_k, 300.0, 0.5, "at the nozzle's temperature, on the bell's plateau")
near(started.volume_l, 0.05, 1e-9, "fifty millilitres of glass")
near(started.headspace_l, 0.05 - 0.004053 - 0.005382, 1e-4, "and 40.6 mL of room over it")
near(started.pressure_kpa, 0, 1e-9, "nothing pressing on the cork yet")
assert(not says(t.examine(p, 3, 1, bottle), "strains"), "and nothing to say about a lid")

-- Ten steps of two seconds, watched one at a time: the gas is made
-- inside the glass and has nowhere to go.
local last_co2, last_kpa, last_made = 0, 0, math.huge
for step = 1, STEPS do
    t.run_seconds(2)
    local reading = assert(t.vessel(bottle))
    local co2 = co2_in(bottle)
    local made = co2 - last_co2
    if step == 1 then
        near(co2, FIRST_CO2, 1e-6, "the first step is base_rate times 2.650 M")
    end
    assert(co2 > last_co2, ("the CO2 grows every step: %g then %g"):format(last_co2, co2))
    -- THE decay: every step makes less than the one before it, because
    -- the sugar it reads is thinner. Under the old law that read a bare
    -- mole count these ten helpings were identical.
    assert(
        made < last_made,
        ("each step makes less than the last: %g then %g"):format(last_made, made)
    )
    assert(
        reading.pressure_kpa > last_kpa,
        ("and so does the gauge: %g then %g"):format(last_kpa, reading.pressure_kpa)
    )
    near(room_co2(), 0, 1e-12, ("nothing reached the room on step %d"):format(step))
    last_co2, last_kpa, last_made = co2, reading.pressure_kpa, made
    -- Three steps buy the 0.00225 mol the warning costs, by the
    -- arithmetic at the top of this file. Before that the bottle is
    -- merely pressurised; from there on the sentence is there and never
    -- goes away while the sugar lasts.
    local straining = says(t.examine(p, 3, 1, bottle), "It strains against its lid.")
    if step < STRAIN_STEP then
        assert(
            reading.pressure_kpa < STRAIN,
            ("under the strain on step %d: %g kPa"):format(step, reading.pressure_kpa)
        )
        assert(not straining, ("and the bottle is quiet on step %d"):format(step))
    else
        assert(
            reading.pressure_kpa > STRAIN,
            ("over the strain by step %d: %g kPa"):format(step, reading.pressure_kpa)
        )
        assert(straining, ("and the bottle says so on step %d"):format(step))
    end
end

near(last_co2, TEN_STEPS_CO2, 1e-6, "ten steps of fermentation, all of it kept")
assert(last_kpa > 600.0, "a bottle under real pressure: " .. last_kpa)
-- The brew is a brew, not just a gas source: what the sugar became is
-- in there too, two of ethanol for every one of it. Counted over BOTH
-- phases, because ethanol has a real vapour curve (substances/
-- ethanol.luau) and a trace of it is standing in the headspace with
-- the CO2 -- which is also part of what the gauge is reading.
local spirit = assert(t.vessel(bottle)).contents.ethanol
near(
    assert(spirit.liquid) + (spirit.gas or 0),
    last_co2,
    1e-9,
    "as much ethanol as carbon dioxide, which is the recipe"
)
assert(spirit.gas ~= nil and spirit.gas > 0, "and some of it is vapour: " .. tostring(spirit.gas))

-- ---------------------------------------------------------------
-- TWO: THE SAME BREW, IN AN OPEN GLASS.
--
-- Nine units of water and one of sugar again, off the same taps into
-- the beaker standing on the deck. Everything about it is the bottle's
-- twin except the cork, so the CO2 has one difference to answer to.
-- ---------------------------------------------------------------
brew_into(3, 2, twin)

local twin_start = assert(t.vessel(twin))
assert(not twin_start.sealed, "a beaker has no lid to strain against")
near(twin_start.moles, WATER + SUGAR, 2e-4, "the same quarter of a mole")
near(twin_start.contents.sugar.solid, SUGAR, 1e-9, "and the same unit of sugar")
near(room_co2(), 0, 1e-12, "the room is still clean when it starts")

for step = 1, STEPS do
    t.run_seconds(2)
    if step == 1 then
        near(room_co2(), FIRST_CO2, 1e-6, "the room took the first step's whole 1.32 mmol")
    end
    near(co2_in(twin), 0, 1e-9, "and the glass kept none of it")
    local reading = assert(t.vessel(twin))
    assert(
        reading.pressure_kpa < STRAIN,
        "an open glass never builds a pressure: " .. reading.pressure_kpa
    )
end

assert(
    not says(t.examine(p, 3, 2, twin), "strains"),
    "so it has nothing to say about a lid it does not have"
)
-- The same ten helpings the bottle made, to within the whisker of
-- vapour an open glass loses that a corked one keeps.
-- Plus the sweep's register: carbon that reached the room arrives thin,
-- spread over six tiles, and a room that goes quiet has whatever is left
-- under the floor booked off it (lunatic docs/MATTER-WORLD.md §3 step 8).
-- It left the bottle either way, which is the claim.
near(
    room_co2() + (t.nullified().co2 or 0.0),
    TEN_STEPS_CO2,
    1e-5,
    "ten steps of it, all of it breathed out"
)
-- And the lid held throughout. The bottle went on fermenting while the
-- beaker did, and a decay tails off rather than stopping dead, so its
-- unit of sugar is still not spent after twenty steps -- but every mole
-- it has made is still inside it, short of the 0.05 mol ceiling its
-- sugar is worth and well past what ten steps alone would buy.
local kept = co2_in(bottle)
assert(kept < 2 * SUGAR, "still short of what its sugar could make: " .. kept)
assert(kept > TEN_STEPS_CO2, "and it never stopped while the beaker ran: " .. kept)
assert(co2_in(bottle) > room_co2(), "and it is still holding more than the room ever gathered")
assert(
    says(t.examine(p, 3, 1, bottle), "It strains against its lid."),
    "still straining, with the room around it at a comfortable pressure"
)

-- ---------------------------------------------------------------
-- THREE: THE SAME BREW, ON A HOTPLATE.
--
-- The bell has two ends and only one of them has been asked about so
-- far. `BellCurve` is exactly ZERO outside its own ends
-- (docs/CHEMISTRY.md 7), and fermentation's upper one is
-- `temp_max = 315` (reactions/fermentation.luau) -- so a brew held over
-- it is not slower, it is stopped, and a bottle that went on quietly
-- making gas over a flame would be the failure nothing above would
-- catch: both bottles so far stood on a deck at the plateau.
--
-- The positive control is the whole of section ONE. Same recipe off the
-- same taps into the same corked fifty millilitres, watched for the same
-- ten steps: down there the first step alone was worth FIRST_CO2 and
-- ten were worth TEN_STEPS_CO2. Here ten steps are worth nothing, and
-- "nothing" is measured against that first step.
--
-- A bench of its own, because the one above has no hotplate on it and
-- no tile left to stand one on.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "hot bench",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    rows: [
        "#####",
        "#.g.#",
        "#o..#",
        "#a..#",
        "#####",
    ],
    structures: [(2, 2, "player_spawn"), (1, 3, "apc")],
    items: [(3, 2, "bottle")],
    machines: [(1, 1, "chem_dispenser"), (3, 1, "chem_heater")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
    ],
)]==],
    0
)

-- The same crewman, at the same two arms' length from both machines, so
-- `dial` and `press` above go on working: they name nobody but `p`.
p = t.join()
t.tick()

local hot_taps = assert(t.target_at(p, 1, 1))
local oven = assert(t.target_at(p, 3, 1))
local flask = assert(t.target_at(p, 3, 2, "bottle"))

-- Straight off the taps this time. The mixing glass in section ONE was
-- there to keep a second open vessel of brew out of the room; nothing
-- here is counting the room.
t.click(p, 3, 2, flask)
t.tick()
assert(t.hands(p).held == "bottle", "the bottle is in hand")
t.click(p, 1, 1, hot_taps)
t.tick()
assert(t.hands(p).held == nil, "and docked under the nozzle")
t.click(p, 1, 1, hot_taps)
t.tick()
dial(WATER)
press("water")
dial(SUGAR)
press("sugar")
ui_controls.toggle(p, "eject")
t.run_ticks(2)
assert(t.hands(p).held == "bottle", "and comes back out with the brew in it")

local filled = assert(t.vessel(flask))
assert(filled.sealed, "corked, like the bottle in section ONE")
near(filled.contents.water.liquid, WATER, 2e-3, "nine units of water")
near(filled.contents.sugar.solid, SUGAR, 2e-3, "and one of sugar")

-- Onto the hotplate at 340 K. Well over the 315 the bell dies at, and
-- well under water's boiling point, so what stops the brewing is the
-- rule and not a bottle that boiled its own reactant away. The
-- thermostat closes a twentieth of its gap an atmos pass and never
-- crosses its setpoint (sim/virtual_bath.rs), so a minute is the
-- plateau and then some.
t.click(p, 3, 1, oven)
t.tick()
assert(t.hands(p).held == nil, "into the chamber")
t.click(p, 3, 1, oven)
t.tick()
ui_controls.set(p, "temperature", 340)
ui_controls.toggle(p, "power")
t.run_seconds(60)

local warmed = assert(t.holder_k(flask))
assert(warmed > 320.0, "the chamber is past the bell's ceiling: " .. warmed)

-- It brewed on the way up -- the climb crosses the window -- and that
-- is what makes the rest a measurement rather than an empty bottle:
-- there is sugar in here, and water with it, and a rule that read them
-- would have something to read.
local standing = assert(t.vessel(flask))
local sugar_left = (standing.contents.sugar and standing.contents.sugar.solid) or 0
assert(sugar_left > 0.5 * SUGAR, "with most of its sugar still unspent: " .. sugar_left)
assert(
    (standing.contents.water and standing.contents.water.liquid or 0) > 0.5 * WATER,
    "and its water still liquid, not boiled off"
)

local function spirit_in(vessel): number
    local entry = assert(t.vessel(vessel)).contents.ethanol
    return entry and ((entry.liquid or 0) + (entry.gas or 0)) or 0
end

local hot_co2, hot_spirit = co2_in(flask), spirit_in(flask)
for step = 1, STEPS do
    t.run_seconds(2)
    local made = co2_in(flask) - hot_co2
    local distilled = spirit_in(flask) - hot_spirit
    -- A thousandth of ONE room-temperature step, over ten of them. The
    -- bottle is corked, so neither number has anywhere to go but a
    -- reaction: what is not being made is not being made.
    assert(
        made < FIRST_CO2 * 1e-3,
        ("step %d made carbon dioxide over temp_max: %g"):format(step, made)
    )
    assert(
        distilled < FIRST_CO2 * 1e-3,
        ("step %d made ethanol over temp_max: %g"):format(step, distilled)
    )
end
assert(
    assert(t.holder_k(flask)) > 315.0,
    "and it was over 315 K the whole way: " .. tostring(t.holder_k(flask))
)

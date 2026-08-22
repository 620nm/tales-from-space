-- Caustic vapours, end to end: dispense a chemical, heat it, and the
-- room fills with something that gets into people.
--
-- The whole chain in one spec, and every link is a thing a player does.
-- Press a button on a dispenser; put the beaker in a heater; dial it;
-- switch it on. Nothing else. What happens after that is physics: the
-- reaction gate opens at 420 K, the liquid pairs off into gas, the gas
-- leaves the open beaker for the room (sim/chemistry/vent.rs), the room
-- carries it to the tile a crewman is standing on, and their next
-- breath keeps nine tenths of it (sim/breathing.rs, `absorb_breath`).
--
-- Two crewmen, differing in ONE thing: one of them opened a tank. That
-- is the whole safety story, and it costs the engine no check at all --
-- a tank's gas has no `inhale`, so a body breathing from one keeps
-- nothing whatever is standing in the room around it.
--
-- CHLORINE rather than ammonia, for two reasons that are both facts
-- about the bench rather than preferences: the dispenser stocks
-- chlorine and does not stock ammonia (ammonia is synthesized, machines
-- /chem_dispenser.luau), and chlorine's gas gate is at 420 K against
-- ammonia's 700 (reactions/chlorine_gas.luau explains why they differ).
-- The shorter chain is the one worth spending a spec on.
--
-- TWO BATCHES, and that is the calibration talking. One beaker of
-- chlorine makes 0.625 mol of gas, which in a four-tile room is half a
-- kilopascal -- about six oxy a breath, against the five a good breath
-- heals back. Survivable, and nearly invisible. Two batches doubles it
-- and the arithmetic tips. That is exactly the shape substances/
-- cl2.luau describes, and a spec that only made one batch would be
-- asserting a coin flip.
local BREATH = 160 -- one breath cycle, 8 s at 20 Hz

t.world([==[(
    name: "fume closet",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "######",
        "#..#g#",
        "#oa###",
        "######",
    ],
    spawns: [(1, 2), (2, 2)],
    items: [(1, 2, "beaker"), (1, 2, "oxygen_tank")],
    machines: [(1, 1, "chem_dispenser"), (2, 1, "chem_heater")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3),
        (1, 2, 3), (2, 2, 3),
    ],
)]==], 0)

local chemist = t.join("engineer")
local diver = t.join("engineer")
t.run_ticks(2)

local dispenser = t.target_at(1, 1)
local heater = t.target_at(2, 1)

-- What the whole closet holds of a gas. An open vessel breathes into
-- the air, and the air moves between tiles the moment it is there, so
-- the room is the only place a gas can honestly be counted.
local function room(key)
    local n = 0
    for x = 1, 2 do
        for y = 1, 2 do
            local gases = t.room_gas(x, y)
            n = n + ((gases and gases[key]) or 0)
        end
    end
    return n
end

local function dock(machine, x, y)
    t.click(chemist, x, y, machine)
    t.tick()
end

local function panel(machine, x, y)
    t.click(chemist, x, y, machine)
    t.tick()
end

local function eject()
    t.ui_act(chemist, "toggle", '{"field":"eject"}')
    t.run_ticks(2)
end

-- ---------------------------------------------------------------
-- ONE: THE DIVER GETS READY, AND THE CHEMIST DOES NOT.
--
-- Apparatus is already on every outfit's face -- a job that issues
-- breathing gear in a bag issues it too late. The tank is the act.
-- ---------------------------------------------------------------
assert(t.worn(diver).mask == "breath_mask", "the shift starts with apparatus on")
t.click(diver, 1, 2, t.target_at(1, 2, "oxygen_tank"))
t.run_ticks(2)
assert(t.hands(diver).held == "oxygen_tank", "the tank is in hand")
t.use_self(diver)
t.run_ticks(2)
local supply = t.vitals(diver)
assert(supply ~= nil and supply.tank ~= nil, "and the valve is open")

-- ---------------------------------------------------------------
-- TWO: TWO BEAKERS OF CHLORINE, HEATED PAST THE GATE.
-- ---------------------------------------------------------------
t.click(chemist, 1, 2, t.target_at(1, 2, "beaker"))
t.run_ticks(2)
assert(t.hands(chemist).held == "beaker", "the beaker is in hand")

local function batch()
    dock(dispenser, 1, 1)
    panel(dispenser, 1, 1)
    t.ui_act(chemist, "toggle", '{"field":"dispense","option":"chlorine"}')
    t.run_ticks(2)
    t.ui_act(chemist, "toggle", '{"field":"dispense","option":"chlorine"}')
    t.run_ticks(2)
    eject()
    assert(t.hands(chemist).held == "beaker", "the vessel comes back out")

    dock(heater, 2, 1)
    panel(heater, 2, 1)
    t.ui_act(chemist, "set", '{"field":"temperature","value":460}')
    t.run_ticks(2)
    t.ui_act(chemist, "toggle", '{"field":"power"}')
    t.run_seconds(90)
    t.ui_act(chemist, "toggle", '{"field":"power"}')
    t.run_ticks(2)
    eject()
end

batch()
local one = room("cl2")
assert(one > 0.3, "one batch put chlorine gas in the room: " .. one .. " mol")
batch()
local two = room("cl2")
assert(two > one, "and the second batch put more there: " .. two .. " mol")

-- The number the calibration is written against, said out loud.
local partial = t.room_pressure(1, 2)
assert(partial ~= nil and partial > 0, "the closet still has air in it")

-- ---------------------------------------------------------------
-- THREE: TEN BREATHS.
--
-- The chemist is breathing the room; the diver is breathing a bottle.
-- ---------------------------------------------------------------
for _ = 1, 9 do
    t.run_ticks(BREATH)
end

-- WHERE THE PROOF IS, and why it is not a blood reading.
--
-- `t.blood(chemist).cl2` is zero here and that is correct rather than
-- disappointing. A breath in this room delivers about 6e-4 mol;
-- metabolism takes up to 0.02 mol a trip, thirty times as much, and it
-- runs in the SAME TICK as the breath and immediately after it
-- (sim/tick.rs: BREATH_EVERY is a multiple of METABOLISM_EVERY). So
-- what arrives has been spent before any tick a spec could sample
-- between. The reading a player has is the one asserted instead: their
-- own oxy, climbing.
--
-- The blood ledger itself is covered where it can be held still --
-- crates/lunatic-server/src/sim/tests/vapors.rs, against a fixture
-- reagent that does not metabolize.
t.run_ticks(BREATH)
assert(t.blood(chemist) ~= nil, "a body has a bloodstream to read")
assert(t.health(chemist).oxy > 10, "it is hurting them: " .. t.health(chemist).oxy)
assert(t.health(chemist).state ~= "dead", "but they are still on their feet")

assert((t.blood(diver).cl2 or 0) == 0, "the valve kept it out of the diver")
assert(t.health(diver).oxy == 0, "who is entirely fine: " .. t.health(diver).oxy)

-- ---------------------------------------------------------------
-- FOUR: ONE ROW, NOT NINETY.
--
-- The first breath of a substance is a ledger row and the rest are not
-- (sim/breathing.rs, the ReactedInHolder precedent). Ten breaths in a
-- cloud is a crewman who walked into one, once.
-- ---------------------------------------------------------------
local rows = 0
for _, row in ipairs(t.ledger_rows("Inhaled")) do
    if row.substance == "cl2" then
        rows = rows + 1
    end
end
assert(rows == 1, "one row for ten breaths of it: " .. rows)

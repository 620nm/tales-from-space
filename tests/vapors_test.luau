-- Caustic vapours, end to end: press a button, tip the bottle out, and
-- the room fills with something that gets into people.
--
-- The whole chain in one spec, and every link is a thing a player does.
-- Press a button on a dispenser; carry the bottle away; tip it onto the
-- deck. Nothing else. What happens after that is physics: liquid
-- chlorine on a 293 K floor is a hundred kelvin over its own boiling
-- point, so it flashes to gas where it lands, the room carries it to
-- the tile the next crewman is standing on, and their next breath
-- keeps nine tenths of it (sim/breathing.rs, `absorb_breath`).
--
-- ONE ID PER MOLECULE is what this spec is really about. There used to
-- be a `chlorine` reagent and a `cl2` gas beside it with a fictional
-- 420 K reaction as the door between them, and the way to gas a room
-- was to heat a beaker until the door opened. There is no door now:
-- `chlorine` IS Cl2, the dispenser hands it over as the liquid a
-- pressurised bottle holds, and the way to gas a room is to open the
-- bottle. A phase is something a substance REACHES, and the whole
-- accident is one careless gesture rather than a recipe.
--
-- Two crewmen, differing in ONE thing: one of them opened a tank. That
-- is the whole safety story, and it costs the engine no check at all --
-- a tank's gas has no `inhale`, so a body breathing from one keeps
-- nothing of whatever is standing in the room around it.
--
-- ...and then the machine that was built for this. A scrubber pointed
-- at chlorine takes chlorine out of the room and leaves the air, which
-- is a question about WHICH gas and therefore asserted in moles.
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
        "#######",
        "#....##",
        "#oa.g##",
        "#######",
    ],
    spawns: [(1, 2), (4, 2)],
    items: [(1, 2, "bottle"), (4, 2, "oxygen_tank")],
    machines: [(1, 1, "chem_dispenser")],
    // The waste main runs out under the east wall, so what the scrubber
    // takes has somewhere to go that is not the room. Layer 2, where a
    // scrubber lives.
    pipes: [(5, 1, 2), (6, 1, 2)],
    // tg's scrubber, spelled out: pointed at a roster with the dial
    // wide open and no floor under it. A placement that SAYS nothing
    // is a return grille instead (scrubber_floor_test.luau).
    structures: [(4, 1, "air_scrubber", { "whole_air": false, "rate_lps": 200.0, "floor_kpa": 0.0 })],
    cables: [
        (1, 1, 1, 0, 2), (1, 1, 1, 0, 4), (1, 1, 2, 0, 2), (1, 1, 2, 0, 4),
        (2, 1, 1, 0, 2), (2, 1, 1, 0, 4), (2, 1, 1, 0, 8), (2, 1, 2, 0, 2),
        (2, 1, 2, 0, 4), (2, 1, 2, 0, 8), (3, 1, 1, 0, 2), (3, 1, 1, 0, 4),
        (3, 1, 1, 0, 8), (3, 1, 2, 0, 2), (3, 1, 2, 0, 4), (3, 1, 2, 0, 8),
        (4, 1, 1, 0, 2), (4, 1, 1, 0, 8), (4, 1, 2, 0, 2), (4, 1, 2, 0, 8),
        (1, 2, 1, 0, 1), (1, 2, 1, 0, 4), (1, 2, 2, 0, 1), (1, 2, 2, 0, 4),
        (2, 2, 1, 0, 1), (2, 2, 1, 0, 4), (2, 2, 1, 0, 8), (2, 2, 2, 0, 1),
        (2, 2, 2, 0, 4), (2, 2, 2, 0, 8), (3, 2, 1, 0, 1), (3, 2, 1, 0, 4),
        (3, 2, 1, 0, 8), (3, 2, 2, 0, 1), (3, 2, 2, 0, 4), (3, 2, 2, 0, 8),
        (4, 2, 1, 0, 1), (4, 2, 1, 0, 8), (4, 2, 2, 0, 1), (4, 2, 2, 0, 8),
    ],
)]==], 0)

local chemist = t.join("engineer")
local diver = t.join("engineer")
t.run_ticks(2)

local dispenser = t.target_at(1, 1)
local scrubber = t.target_at(4, 1, "air_scrubber")
local jar = t.target_at(1, 2, "bottle")

-- What the whole closet holds of a gas. A tipped-out puddle boils on
-- the tile it landed on and the air moves between tiles the moment it
-- is there, so the room is the only place a gas can honestly be
-- counted.
local ROOM = {
    { 1, 1 }, { 2, 1 }, { 3, 1 }, { 4, 1 },
    { 1, 2 }, { 2, 2 }, { 3, 2 }, { 4, 2 },
}
local function room(key)
    local n = 0
    for _, tile in ipairs(ROOM) do
        local gases = t.room_gas(tile[1], tile[2])
        n = n + ((gases and gases[key]) or 0)
    end
    return n
end

local function pipe(key)
    local held = t.pipe_gas(5, 1, 2)
    return (held and held[key]) or 0.0
end

-- ---------------------------------------------------------------
-- ONE: THE DIVER GETS READY, AND THE CHEMIST DOES NOT.
--
-- Apparatus is already on every outfit's face -- a job that issues
-- breathing gear in a bag issues it too late. The tank is the act.
-- ---------------------------------------------------------------
assert(t.worn(diver).mask == "breath_mask", "the shift starts with apparatus on")
t.click(diver, 4, 2, t.target_at(4, 2, "oxygen_tank"))
t.run_ticks(2)
assert(t.hands(diver).held == "oxygen_tank", "the tank is in hand")
t.use_self(diver)
t.run_ticks(2)
local supply = t.vitals(diver)
assert(supply ~= nil and supply.tank ~= nil, "and the valve is open")

-- ---------------------------------------------------------------
-- TWO: A BOTTLE OF LIQUID CHLORINE, TIPPED OUT ON THE FLOOR.
--
-- A press of chlorine over an OPEN vessel is refused -- the machine
-- says so and writes no row -- because what landed would leave through
-- the same mouth before anybody looked up (D19). Into the bottle it
-- lands and condenses under its own vapour pressure, and what the
-- chemist is then carrying is a pressurised bottle of liquid chlorine.
--
-- THREE BOTTLEFULS, and that is the calibration talking. A full press
-- is 1.25 mol and about four fifths of it comes back out of the bottle
-- as liquid -- the saturated vapour over the top stays behind, because
-- a tip takes the CONDENSED phases and nothing else. Three quarters of
-- a mole loose in an eight-tile closet is a quarter of a kilopascal,
-- which is three oxy a breath against the five a good breath heals
-- back: not gentle, INVISIBLE (substances/chlorine.luau). Three
-- bottlefuls is nearly a whole kilopascal and the arithmetic tips. A
-- spec that tipped one bottle would be asserting a coin flip.
-- ---------------------------------------------------------------
local PRESS = 1.25

local function bottleful()
    t.click(chemist, 1, 2, jar)
    t.run_ticks(2)
    assert(t.hands(chemist).held == "bottle", "the bottle is in hand")

    t.click(chemist, 1, 1, dispenser)
    t.tick()
    assert(t.hands(chemist).held == nil, "and it goes into the dock")
    t.click(chemist, 1, 1, dispenser)
    t.tick()
    t.ui_act(chemist, "set", '{"field":"amount","value":' .. PRESS .. '}')
    t.run_ticks(2)
    t.ui_act(chemist, "toggle", '{"field":"dispense","option":"chlorine"}')
    -- The press lands in one pass; the sweep takes a few more to walk
    -- the superheat down onto the saturation line.
    t.run_seconds(10)
    t.ui_act(chemist, "toggle", '{"field":"eject"}')
    t.run_ticks(2)
    assert(t.hands(chemist).held == "bottle", "the vessel comes back out")

    -- ...and the gesture that costs a shift: a click on the deck tips a
    -- vessel's whole condensed content onto it (items/bottle.luau).
    t.click(chemist, 2, 1)
    t.run_seconds(20)
    t.drop(chemist)
    t.tick()
end

bottleful()
local one = room("chlorine")
assert(one > 0.5, "one bottleful boiled off into the room: " .. one .. " mol")

-- PV = nRT, and both halves are read off the sim rather than pinned:
-- the closet is eight cubic metres, so the partial pressure the moles
-- imply is the partial pressure a gauge would read.
local function partial()
    return room("chlorine") * 8.314 * t.room_temperature(2, 1) / (#ROOM * 1000.0)
end
assert(partial() > 0.2, "which is a real partial pressure: " .. partial() .. " kPa")

bottleful()
local two = room("chlorine")
assert(two > one, "and the second bottleful put more there: " .. two .. " mol")
bottleful()
local three = room("chlorine")
assert(three > two, "and the third more again: " .. three .. " mol")
assert(partial() > 0.75,
    "which is a closet nobody should be standing in: " .. partial() .. " kPa")

-- ---------------------------------------------------------------
-- THREE: TEN BREATHS.
--
-- The chemist is breathing the room; the diver is breathing a bottle.
--
-- WHERE THE PROOF IS, and why it is not a blood reading.
-- `t.blood(chemist).chlorine` is zero here and that is correct rather
-- than disappointing. A breath in this room delivers well under a
-- millimole; metabolism takes up to 0.02 mol a trip, and it runs in the
-- SAME TICK as the breath and immediately after it (sim/tick.rs:
-- BREATH_EVERY is a multiple of METABOLISM_EVERY). So what arrives has
-- been spent before any tick a spec could sample between. The reading a
-- player has is the one asserted instead: their own oxy, climbing.
--
-- The blood ledger itself is covered where it can be held still --
-- crates/lunatic-server/src/sim/tests/vapors.rs, against a fixture
-- reagent that does not metabolize.
-- ---------------------------------------------------------------
for _ = 1, 10 do
    t.run_ticks(BREATH)
end

assert(t.blood(chemist) ~= nil, "a body has a bloodstream to read")
assert(t.health(chemist).oxy > 10, "it is hurting them: " .. t.health(chemist).oxy)
assert(t.health(chemist).animate, "but they are still on their feet")

assert((t.blood(diver).chlorine or 0) == 0, "the valve kept it out of the diver")
assert(t.health(diver).oxy == 0, "who is entirely fine: " .. t.health(diver).oxy)

-- ONE ROW, NOT NINETY. The first breath of a substance is a ledger row
-- and the rest are not (sim/breathing.rs, the ReactedInHolder
-- precedent). Ten breaths in a cloud is a crewman who walked into one,
-- once.
local rows = 0
for _, row in ipairs(t.ledger_rows("Inhaled")) do
    if row.substance == "chlorine" then
        rows = rows + 1
    end
end
assert(rows == 1, "one row for ten breaths of it: " .. rows)

-- ---------------------------------------------------------------
-- FOUR: AND THE MACHINE THAT WAS BUILT FOR THIS.
--
-- A scrubber pointed at one substance takes that substance out of the
-- room and leaves the rest. Chlorine is on its roster because chlorine
-- MODELS a gas -- the roster is every substance with a gas phase, not
-- only the ones that are permanently gas (sim/ui/settings/scrubber.rs)
-- -- and that is exactly the fix a station needs the day its chemist
-- makes something with a boiling point. Before it, a filter and a
-- scrubber could be pointed at oxygen and nitrogen and nothing else,
-- so the one accident the kit exists for was the one it could not
-- answer.
--
-- WHAT IS ASSERTED IS MOLES ACROSS A BOUNDARY, not an empty room. This
-- main is a dead end -- two lengths of commissioned pipe, already full
-- of air at an atmosphere -- so the machine works until the run is at
-- the room's own pressure and then stops, which is correct and is what
-- a real station answers with a plant at the far end. The claim is
-- that what left the room ARRIVED in the main, and that it was the
-- chlorine that left and not the air.
-- ---------------------------------------------------------------
local before_room = room("chlorine")
local before_pipe = pipe("chlorine")
local before_o2 = room("o2")
local before_n2 = room("n2")

-- THE DIVER WORKS IT, and that is not staging. The chemist is standing
-- in the cloud with ten breaths of it in them; the crewman who opened a
-- tank is the crewman who can still cross the room and press a switch.
t.click(diver, 4, 1, scrubber)
t.tick()
local roster = {}
for _, sw in ipairs(t.ui(diver).toggles) do
    if sw.field == "filter" then
        roster[sw.option] = sw.on
    end
end
assert(roster.chlorine == false, "chlorine is on the roster, and starts unselected")

t.ui_act(diver, "toggle", '{"field":"filter","option":"chlorine"}')
t.ui_act(diver, "toggle", '{"field":"power"}')
-- Five minutes. A scrubber only ever works the tile it stands on and
-- the rest of the room refills that tile by ordinary diffusion between
-- passes, so this is one mouth against six neighbours -- which is why
-- the books are taken over the whole room and never over the machine's
-- own tile.
t.run_seconds(300)

local moved = before_room - room("chlorine")
assert(moved > 0.25 * before_room,
    "a quarter of the cloud is out of the air the crew is in: " .. moved .. " mol")
-- A thousandth of slack rather than a billionth, because the main is
-- not the only sink in the closet: there is a crewman standing in the
-- cloud without a mask on, and every breath he takes keeps nine tenths
-- of what was in it.
assert(math.abs((pipe("chlorine") - before_pipe) - moved) < 5e-3,
    "and all but a breath of it is in the waste main, not lost: "
        .. (pipe("chlorine") - before_pipe) .. " vs " .. moved)

-- ...and it took the chlorine and NOT the air, which is the whole
-- difference between a scrubber and a siphon.
assert(math.abs(room("o2") - before_o2) < 0.05 * before_o2, "the oxygen stayed")
assert(math.abs(room("n2") - before_n2) < 0.05 * before_n2, "and so did the nitrogen")
assert(t.room_pressure(2, 2) > 80.0,
    "the closet still has its atmosphere: " .. t.room_pressure(2, 2) .. " kPa")

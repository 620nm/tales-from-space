-- IDENTITY: nitrous oxide, made on a bench and poured out of a map,
-- and there is only ONE of it.
--
-- This is the spec the whole milestone is for. tg carries nitrous
-- oxide twice: `/datum/gas/nitrous_oxide` lives in the air and is what
-- an atmos scrubber, a canister and a crewman's lungs deal with, and
-- `/datum/reagent/nitrous_oxide` lives in a beaker and is what
-- chemistry makes -- and the two never meet. A chemist who synthesised
-- a bottle of the reagent could not put it in a canister, could not
-- point a scrubber at it, and could not gas a room with it; a mapper
-- who filled a chamber with the gas could not hand a drop of it to the
-- pharmacy. They are two ids with one name.
--
-- Here they are one id. The bench route below makes `n2o` out of
-- ammonia and oxygen (reactions/nitrous_oxide.luau), the map route
-- pours `n2o` out of an air preset (the same grammar
-- tfs/maps/chillstation.ron:474,1065 uses for the tank in the science
-- annex), and every surface that reads either of them reads the same
-- registry row: the vessel window, the examine pane, the gas
-- analyzer's printout, the canister's gauge, the scrubber's filter
-- roster, and a body's lungs.
--
-- WHAT A BENCH BOTTLE CANNOT DO, stated rather than hidden. Nothing a
-- player can do moves gas OUT of a sealed vessel: the bottle's valve
-- gesture (items/bottle.luau) draws gas from a fixture into the
-- bottle, and pouring and tipping take the condensed phases only. So
-- the bench route is read where a bench bottle can be read -- its
-- window and its examine pane -- and the machine-side surfaces are
-- read off the map route. The claim is that both name the same thing,
-- which is exactly what a translator between two ids could never make
-- true.

local BREATH = 160 -- one breath cycle, 8 s at 20 Hz

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function has_text(lines, needle)
    for _, line in ipairs(lines) do
        if string.find(line, needle, 1, true) ~= nil then
            return line
        end
    end
    return nil
end

-- ---------------------------------------------------------------
-- ONE: THE BENCH ROUTE.
--
-- tg's own recipe, balanced as molecules: 2 NH3 + 2 O2 -> N2O + 3 H2O
-- (reactions/nitrous_oxide.luau, 525/550/575/600 K, oxygen gate 100
-- kPa). The oxygen comes off a canister because it left the dispenser
-- shelf when the twins were folded, and the ammonia is liquid under
-- the bottle's own lid -- which is the shape gas_fill_test.luau covers
-- in full. What is asserted HERE is only what comes out with the
-- lid still on: a vessel window and an examine pane, both naming one
-- substance.
-- ---------------------------------------------------------------
t.world([==[(
    name: "chem bench",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#######",
        "#o.a.g#",
        "#.....#",
        "#.....#",
        "#######",
    ],
    spawns: [(2, 2)],
    items: [(2, 3, "bottle")],
    machines: [(1, 2, "chem_dispenser"), (3, 2, "chem_heater")],
    structures: [(2, 1, "canister")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3),
    ],
)]==], 0)

t.set_environment({ sink_k = 293.15, insolation = 0.0 })
local chemist = t.join()
t.tick()

local dispenser = t.target_at(1, 2)
local heater = t.target_at(3, 2)
local supply = t.target_at(2, 1)
local jar = t.target_at(2, 3, "bottle")
assert(dispenser ~= nil and heater ~= nil and supply ~= nil and jar ~= nil, "the bench is set")

-- Twenty atmospheres of oxygen on the line: a quarter of what a supply
-- bottle ships holding, and the only place the recipe's gas share can
-- come from (docs/BENCH.md 4).
assert(t.charge_vessel(2, 1, "o2", 2000.0), "the line is charged")
t.run_seconds(2)

t.click(chemist, 2, 3, jar)
t.run_ticks(2)
assert(t.hands(chemist).held == "bottle", "the bottle is in hand")
t.click(chemist, 2, 1, supply)
t.run_ticks(4)
local charge = t.vessel(jar).contents.o2.gas
assert(charge > 0.0, "and it came away with oxygen: " .. charge .. " mol")

-- A mole of ammonia, which condenses under the lid the moment it is
-- in there and is the LIQUID phase the recipe names.
t.click(chemist, 1, 2, dispenser)
t.tick()
t.click(chemist, 1, 2, dispenser)
t.tick()
t.ui_act(chemist, "set", '{"field":"amount","value":1.0}')
t.run_ticks(2)
t.ui_act(chemist, "toggle", '{"field":"dispense","option":"ammonia"}')
t.run_ticks(4)
t.ui_act(chemist, "toggle", '{"field":"eject"}')
t.run_ticks(2)

t.click(chemist, 3, 2, heater)
t.tick()
t.click(chemist, 3, 2, heater)
t.tick()
t.ui_act(chemist, "set", '{"field":"temperature","value":530}')
t.run_ticks(2)
if t.ui(chemist).toggles[1].on ~= true then
    t.ui_act(chemist, "toggle", '{"field":"power"}')
    t.run_ticks(2)
end
assert(t.ui(chemist).toggles[1].on == true, "the element is on")
t.run_seconds(600)

local made = t.vessel(jar).contents.n2o
assert(made ~= nil and (made.gas or 0.0) > 1e-6,
    "the bench made nitrous oxide: " .. tostring(made and made.gas))
local BENCH_MADE = made.gas
assert(t.vessel(jar).contents.ammonia ~= nil, "out of the liquid ammonia the recipe names")

-- ...and the VESSEL WINDOW names it. `t.vessel` is `ctx.vessel` off
-- the same backend, which is what the chem panel itemises for anybody
-- standing at the bench, and the key it itemises under is the registry
-- id -- so there is no second nitrous oxide for a window to have to
-- choose between.
assert(t.vessel(jar).contents.n2o.gas == BENCH_MADE, "keyed as `n2o` and nothing else")

-- ...and so does the examine pane, in the substance file's own words
-- (sim/examine.rs, `matter_lines`; substances/n2o.luau, `name`).
t.ui_act(chemist, "toggle", '{"field":"power"}')
t.run_ticks(2)
t.ui_act(chemist, "toggle", '{"field":"eject"}')
t.run_ticks(2)
assert(t.hands(chemist).held == "bottle", "the bottle comes back out")
local look = t.examine_held(chemist)
assert(look ~= nil, "a crewman can look at what is in their hand")
assert(has_text(look.lines, "nitrous oxide") ~= nil,
    "and the pane calls it by its name: " .. table.concat(look.lines, " / "))

-- ---------------------------------------------------------------
-- TWO: THE MAP ROUTE, AND THE FOUR MACHINE-SIDE SURFACES.
--
-- The same id, arriving the other way: an air preset naming `n2o`,
-- which is exactly what the science annex's tank on chillstation says.
-- Every reading below is a machine or a body reading the gas, and none
-- of them has to be told which nitrous oxide is meant.
-- ---------------------------------------------------------------
t.world([==[(
    name: "the sleeping chamber",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#.....##",
        "#ag...##",
        "########",
    ],
    spawns: [(4, 1), (4, 2)],
    items: [(4, 1, "analyzer"), (4, 2, "oxygen_tank")],
    air_presets: {
        // chillstation.ron:1065's own recipe, to the digit: a tank of
        // it at 23 MPa, spread over a canister's two cubic metres.
        "n2o_23000kpa": (gases: [("n2o", 9436.868804259688)], temperature_k: 293.15),
        // ...and the chamber a mapper fills on purpose
        // (substances/n2o.luau). One atmosphere of it and nothing
        // else: 101.325 kPa over a cubic metre at T20C is 41.57 mol.
        "sleeping_chamber": (gases: [("n2o", 41.57)], temperature_k: 293.15),
    },
    air: [
        (1, 1, "sleeping_chamber"), (2, 1, "sleeping_chamber"), (3, 1, "sleeping_chamber"),
        (4, 1, "sleeping_chamber"), (5, 1, "sleeping_chamber"),
        (1, 2, "sleeping_chamber"), (2, 2, "sleeping_chamber"), (3, 2, "sleeping_chamber"),
        (4, 2, "sleeping_chamber"), (5, 2, "sleeping_chamber"),
    ],
    // The waste main under the east wall, so what the scrubber takes
    // has somewhere to go that is not the room.
    pipes: [(6, 1, 2), (6, 2, 2)],
    structures: [
        (5, 1, "canister", { "air": "n2o_23000kpa" }),
        (5, 2, "air_scrubber", { "whole_air": false, "rate_lps": 200.0, "floor_kpa": 0.0 }),
    ],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3),
    ],
)]==], 0)

t.set_environment({ sink_k = 293.15, insolation = 0.0 })
local reader = t.join("engineer")
local diver = t.join("engineer")
t.run_ticks(2)

local can = t.target_at(5, 1)
local scrubber = t.target_at(5, 2, "air_scrubber")
assert(can ~= nil and scrubber ~= nil, "the chamber is set")

local ROOM = {}
for x = 1, 5 do
    for y = 1, 2 do
        ROOM[#ROOM + 1] = { x, y }
    end
end

local function room(key)
    local n = 0.0
    for _, tile in ipairs(ROOM) do
        local gases = t.room_gas(tile[1], tile[2])
        n = n + ((gases and gases[key]) or 0.0)
    end
    return n
end

local function pipe(key)
    local held = t.pipe_gas(6, 1, 2)
    return (held and held[key]) or 0.0
end

-- SURFACE 1 -- THE CANISTER. The gauge and the itemised contents are
-- the same reading a beaker gives, because a canister IS a beaker with
-- a thicker wall (docs/CHEMISTRY.md 1).
local bottle = t.vessel(can)
assert(bottle.contents.n2o ~= nil, "the canister is holding `n2o`")
assert(bottle.contents.n2o.gas > 1000.0,
    "and a lot of it: " .. bottle.contents.n2o.gas .. " mol")
near(t.canister_pressure(5, 1), bottle.pressure_kpa, 1e-9,
    "the tile's gauge and the vessel reading are one number")
local MAPPED = bottle.contents.n2o.gas

-- SURFACE 2 -- THE ANALYZER, which prints the registry's display name
-- and no table of its own (items/analyzer.luau deleted the one it used
-- to carry). The same three words the examine pane used on the bench
-- bottle, on a completely different route in.
t.click(reader, 4, 1, t.target_at(4, 1, "analyzer"))
t.run_ticks(2)
assert(t.hands(reader).held == "analyzer", "the analyzer is in hand")
local _ = t.messages(reader)
t.click(reader, 5, 1, can)
t.run_ticks(2)
local printed = t.messages(reader)
assert(has_text(printed, "Results of analysis") ~= nil, "it read the canister")
local named = has_text(printed, "Nitrous oxide:")
assert(named ~= nil, "and named it: " .. table.concat(printed, " / "))
assert(string.find(named, "(100 %)", 1, true) ~= nil,
    "the whole of what is in there is the one substance: " .. named)

-- ...and the chamber the same map PAINTED, which is the other half of
-- the map route: one atmosphere of `n2o` over every tile and nothing
-- else in the air at all (substances/n2o.luau: "a chamber a mapper
-- fills on purpose").
local loose = room("n2o")
assert(loose > 400.0, "the chamber is standing in it: " .. loose .. " mol")
near(room("o2"), 0.0, 1e-9, "and there is no oxygen in here whatsoever")
assert(t.room_pressure(2, 2) > 95.0,
    "at an ordinary pressure, which is what makes it a trap rather than a vacuum: "
        .. t.room_pressure(2, 2) .. " kPa")
local LOADED = loose + MAPPED

-- The analyzer over a TILE of it prints the same three words it
-- printed over the canister. The air in the room and the gas in the
-- bottle are one substance answering one readout, through the same
-- `sim.matter_read` (items/analyzer.luau reads a machine and a turf
-- through one printer).
local _ = t.messages(reader)
t.click(reader, 3, 1)
t.run_ticks(2)
local air = t.messages(reader)
assert(has_text(air, "Results of analysis of the air.") ~= nil, "it read the air")
local air_named = has_text(air, "Nitrous oxide:")
assert(air_named ~= nil, "and named it the same way: " .. table.concat(air, " / "))
assert(string.find(air_named, "(100 %)", 1, true) ~= nil,
    "and it is the whole of what a crewman in here is breathing: " .. air_named)

-- SURFACE 3 -- A PAIR OF LUNGS. Two crewmen, differing in one thing:
-- one of them opened a tank.
--
-- WHAT A BODY KEEPS of it is NOTHING, and that is the substance file
-- talking rather than a gap in this spec: substances/n2o.luau authors
-- no `inhale`, because tg's sleeping agent puts a mob under and this
-- engine has no unconsciousness that is not crit yet. So the harm is
-- DISPLACEMENT -- a chamber holding one atmosphere of one gas has no
-- oxygen in it at all -- and the blood stays clean. Both halves are
-- the same registry row answering two questions (sim/breathing.rs,
-- `absorb_breath`).
--
-- The scrubber stays SWITCHED OFF for this: a machine drawing two
-- hundred litres a second out of one tile is a wind, and a spec about
-- breathing should not be a spec about being blown across a room.
assert(t.worn(diver).mask == "breath_mask", "the shift starts with apparatus on")
t.click(diver, 4, 2, t.target_at(4, 2, "oxygen_tank"))
t.run_ticks(2)
assert(t.hands(diver).held == "oxygen_tank", "the tank is in hand")
t.use_self(diver)
t.run_ticks(2)
local supply_open = t.vitals(diver)
assert(supply_open ~= nil and supply_open.tank ~= nil, "and the valve is open")

for _ = 1, 8 do
    t.run_ticks(BREATH)
end
assert(t.health(reader).oxy > 10,
    "the one breathing the chamber is drowning in it: " .. t.health(reader).oxy)
assert((t.blood(reader).n2o or 0) == 0,
    "and keeping none of it, because the file authors no `inhale`")
assert(t.health(diver).oxy == 0, "the one on a tank is fine: " .. t.health(diver).oxy)
assert((t.blood(diver).n2o or 0) == 0, "and keeps none of it either")

-- SURFACE 4 -- THE SCRUBBER, and the roster it offers. The roster is
-- every substance the registry models a gas phase for
-- (sim/ui/settings/scrubber.rs), so a machine that could once be
-- pointed at oxygen and nitrogen and nothing else can be pointed at
-- this. ONE entry, because there is one substance -- a pack carrying
-- an atmos `n2o` beside a chemistry one would put two rows on this
-- panel and give an engineer a choice nobody can make correctly.
--
-- THE DIVER WORKS IT, and that is not staging: the crewman who opened
-- a tank is the crewman who can still cross the room and press a
-- switch.
t.click(diver, 5, 2, scrubber)
t.tick()
local offers = 0
local sleepy_on = nil
for _, sw in ipairs(t.ui(diver).toggles) do
    if sw.field == "filter" and sw.option == "n2o" then
        offers = offers + 1
        sleepy_on = sw.on
    end
end
assert(offers == 1, "the roster offers nitrous oxide exactly once: " .. offers)
assert(sleepy_on == false, "and starts unselected")

-- ...and it WORKS on it, which is the difference between a roster
-- entry and a working machine. What is asserted is MOLES ACROSS A
-- BOUNDARY rather than an empty chamber: this main is a dead end, two
-- lengths of commissioned pipe, so the machine works until the run is
-- at the room's own pressure and then stops -- which is correct, and
-- is what a real station answers with a plant at the far end.
local before_room = room("n2o")
local before_pipe = pipe("n2o")
t.ui_act(diver, "toggle", '{"field":"filter","option":"n2o"}')
t.run_ticks(2)
t.ui_act(diver, "toggle", '{"field":"power"}')
t.run_seconds(120)

local moved = before_room - room("n2o")
assert(moved > 0.5, "the scrubber cleared it out of the air: " .. moved .. " mol")
near(pipe("n2o") - before_pipe, moved, 1e-6,
    "and every mole of it is in the waste main, not lost: "
        .. (pipe("n2o") - before_pipe) .. " vs " .. moved)

-- ---------------------------------------------------------------
-- THREE: ONE ID, SAID ONCE.
--
-- Both routes ended up keyed `n2o`; both were named "nitrous oxide" by
-- a readout that got the word out of the registry rather than out of a
-- table of its own; and no surface anywhere had to ask which of two
-- nitrous oxides it was looking at, because there is one.
-- ---------------------------------------------------------------
assert(BENCH_MADE > 0.0 and MAPPED > 0.0, "both routes put some there")
assert(t.room_gas(2, 2).n2o ~= nil, "the room reads the same key the bench bottle did")

-- ...and the books. Every mole in this chamber came out of the map's
-- own presets and went where a machine put it: the room, the main, or
-- the canister it started in. Nothing reacts with it, nothing
-- metabolizes it, and nothing on this station mints it.
--
-- A millionth of a mole of slack against the fourteen thousand this
-- chamber holds -- a relative 1e-10, which is float summation over a
-- hundred thousand transfers and not a leak.
local closed = t.matter_totals()
near(closed.substances.n2o, LOADED, 1e-6,
    "not one mole of it was made or lost: " .. closed.substances.n2o .. " vs " .. LOADED)

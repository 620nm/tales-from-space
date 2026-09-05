-- A reservoir with the books open.
--
-- stationary_tank_test.luau settles WHAT a tank is -- no valve, no dial,
-- four open mouths, one body of gas shared with whatever it is welded to
-- -- and proves the direction of travel on a gauge. This file weighs the
-- same machine on the mole and the joule: a gauge cannot tell a transfer
-- from a leak, since a vessel that emptied into a run and one that
-- emptied into nothing read the same AT THE VESSEL. The endpoint is
-- arithmetic, not a direction, either -- tg's `reconcile_air`
-- (datum_pipeline.dm:239-252) pools every holder and hands the pool back
-- out by VOLUME, so a settled vessel-and-run is one body at one molar
-- density, at nRT/V over the whole of it.

-- NOBODY IN HERE IS BREATHING. A crewman with lungs is a chemical
-- plant standing in the room: his lungs are a driven vessel that holds
-- several litres of the air inside itself and turns what it takes in
-- into something else (docs/BIOLOGY.md, `sim/holder/bellows.rs`). That
-- is a source and a sink, and the books below are the ATMOSPHERICS
-- engine's -- so the crew are switched off as scaffolding, the same
-- standing `t.set_health` has.
t.set_breathing(false)

local R = 8.314
local T20C = 293.15
local TANK_M3 = 2.5
-- tg's UNARY_PIPE_VOLUME * 2 per raw length (atmos_piping.dm:42), and the
-- 200 L component mixture every mouth pays into the net it opens onto
-- (components_base.dm:36-41): a run bolted to a vessel is its own lengths
-- plus one mouth.
local PIPE_M3 = 0.070
local PORT_M3 = 0.200

-- A document's words are labels: `{id=…}` for one the engine names,
-- `{text=…}` for one content wrote (docs/tgui/labels.md).
local function word(label)
    if type(label) ~= "table" then return label end
    return label.id or label.text
end

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

-- Moles in an analyser's reading, off whichever holder.
local function total(mix)
    local sum = 0.0
    for _, moles in pairs(mix or {}) do
        sum = sum + moles
    end
    return sum
end

-- What `moles` in a volume comes to, kPa.
local function pressure_of(moles, volume_m3, kelvin)
    return moles * R * kelvin / volume_m3 / 1000.0
end

-- The warmth off the open window's contents block, which is where a
-- vessel's own numbers live now (docs/tgui/matter-block.md).
local function window_k(p)
    for _, b in ipairs(t.ui(p).matter or {}) do
        if word(b.section) == "holder.contents" then
            return b.temperature_k
        end
    end
    return nil
end

-- ---------------------------------------------------------------
-- ONE VESSEL, ONE RUN, ONE PASS. A charged tank bolted to three lengths
-- of main, handed over at one atmosphere: both ends start somewhere, and
-- the settled number is neither.
-- ---------------------------------------------------------------
t.world([==[(
    name: "one vessel, one run",
    legend: { '.': (turf: Plating), '#': (turf: Wall) },
    rows: ["#######", "#.....#", "#######"],
    spawns: [(1, 1)],
    structures: [(2, 1, "stationary_tank", "anchored", ("o2", 9000.0))],
    pipes: [(3, 1, 4), (4, 1, 4), (5, 1, 4)],
)]==], 7)

local p = t.join()
t.tick()

local RUN_M3 = 3.0 * PIPE_M3 + PORT_M3
local tank_0 = total(t.tank_gas(2, 1))
local run_0 = total(t.pipe_gas(3, 1))
near(t.tank_pressure(2, 1), 9000.0, 0.01, "the vessel as authored")
near(t.pipe_pressure(3, 1), 101.325, 0.01, "the run at one atmosphere")

local settled_kpa = pressure_of(tank_0 + run_0, TANK_M3 + RUN_M3, T20C)

-- ONE atmos pass -- ten ticks -- and it is over. tg equalises completely
-- in a pass and so does this: a vessel is not a machine working towards a
-- setpoint, it is a room with steel walls.
t.run_ticks(10)
near(t.tank_pressure(2, 1), settled_kpa, settled_kpa * 1e-9,
    "one pass lands the vessel on the volume-weighted pressure")
near(t.pipe_pressure(3, 1), settled_kpa, settled_kpa * 1e-9, "and the run with it")

-- What the run gained is what the vessel lost: a transfer, not two
-- agreeable gauges.
local tank_1 = total(t.tank_gas(2, 1))
local run_1 = total(t.pipe_gas(3, 1))
near(tank_1 + run_1, tank_0 + run_0, (tank_0 + run_0) * 1e-12, "not a mole minted")
near(tank_0 - tank_1, run_1 - run_0, (run_1 - run_0) * 1e-9,
    "and the vessel is what paid for the run's gain")
assert(tank_1 < tank_0, "the vessel emptied INTO the run: " .. tank_0 .. " -> " .. tank_1)

-- One body of gas is one molar density, split by volume.
near(tank_1 / TANK_M3, run_1 / RUN_M3, (tank_1 / TANK_M3) * 1e-12,
    "one density across both, which is what 'split by volume' means")

-- And it stays there. Nothing oscillates, nothing creeps.
t.run_seconds(20)
near(t.tank_pressure(2, 1), settled_kpa, settled_kpa * 1e-9, "settled is settled")
near(total(t.tank_gas(2, 1)), tank_1, 1e-9, "the vessel's book unmoved 20 s on")

-- ---------------------------------------------------------------
-- HEAT TRAVELS WITH THE GAS, AND ONLY WITH THE GAS.
--
-- Back to the settled vessel and run above, warmed. The pass writes
-- DRAWS, never temperatures: a parcel carries its own energy, so a
-- vessel's temperature is never assigned -- it is what the joules in it
-- come to. (Nothing a player can reach makes one pipe hotter than another
-- yet, so the gradient is `t.heat_pipe`: precondition scaffolding with
-- `t.set_health`'s standing, never an assertion.)
-- ---------------------------------------------------------------
local vessel_n = total(t.tank_gas(2, 1))
local run_n = total(t.pipe_gas(3, 1))
local rest_k = t.pipe_temperature(3, 1)
-- One molar heat capacity, taken off the world rather than written down.
-- The vessel answers to it too: the two are one body of gas.
local cv = t.pipe_energy(3, 1) / (run_n * rest_k)

t.click(p, 2, 1, t.target_at(2, 1))
t.tick()
near(window_k(p), rest_k, 1e-6,
    "the vessel's window agrees with an analyser held against the run")

local INJECTED = 10000000.0
local energy_0 = t.pipe_energy(3, 1) + vessel_n * cv * rest_k
t.heat_pipe(3, 1, INJECTED)
t.run_seconds(5)

local hot_k = t.pipe_temperature(3, 1)
local energy_1 = t.pipe_energy(3, 1) + total(t.tank_gas(2, 1)) * cv * hot_k
near(energy_1, energy_0 + INJECTED, (energy_0 + INJECTED) * 1e-9,
    "the joules that went in are the joules that are there")
near(hot_k, (energy_0 + INJECTED) / ((vessel_n + run_n) * cv), 1e-6,
    "and the temperature is that book divided through both holders")
assert(hot_k > rest_k + 40.0, "warmer for it: " .. rest_k .. " -> " .. hot_k .. " K")
near(window_k(p), hot_k, 1e-6,
    "and the vessel came with it -- one body of gas, one temperature")

-- MASS did not move: the split is by volume and both holders were already
-- at one density, so what crossed the mouth was energy on parcels that
-- came straight back.
near(total(t.tank_gas(2, 1)), vessel_n, vessel_n * 1e-12, "the vessel's moles are untouched")
near(total(t.pipe_gas(3, 1)), run_n, run_n * 1e-12, "and so are the run's")

-- ---------------------------------------------------------------
-- TWO VESSELS, TWO GASES, ONE RUN.
--
-- The consequence the tank annex is laid out to avoid, proved so that
-- room's seven UNPLUMBED vessels read as a decision and not an accident:
-- bolt an oxygen tank and a nitrogen tank to one length of pipe and you
-- no longer own an oxygen tank. Free flow has no direction and no valve,
-- so both vessels and the run end up holding the SAME mixture, and the
-- only way back is a filter. (One vessel reconciles at a time here, so a
-- net with two converges over passes where tg's pipeline-wide pool lands
-- in one. Same endpoint, which is what this asserts.)
-- ---------------------------------------------------------------
t.world([==[(
    name: "two vessels, one run",
    legend: { '.': (turf: Plating), '#': (turf: Wall) },
    rows: ["#######", "#.....#", "#######"],
    spawns: [(1, 1)],
    structures: [
        (2, 1, "stationary_tank", "anchored", ("o2", 10000.0)),
        (5, 1, "stationary_tank", "anchored", ("n2", 20000.0)),
    ],
    pipes: [(3, 1, 4), (4, 1, 4)],
)]==], 7)

t.join()
t.tick()

-- Two lengths, and a mouth from each vessel folded in.
local SHARED_M3 = 2.0 * PIPE_M3 + 2.0 * PORT_M3
local o2_0 = t.tank_gas(2, 1).o2 + t.pipe_gas(3, 1).o2
local n2_0 = t.tank_gas(5, 1).n2 + t.pipe_gas(3, 1).n2
assert(t.tank_gas(2, 1).n2 == nil, "the oxygen vessel starts pure")
assert(t.tank_gas(5, 1).o2 == nil, "and so does the nitrogen one")

t.run_seconds(60)

local left, right, between = t.tank_gas(2, 1), t.tank_gas(5, 1), t.pipe_gas(3, 1)
local function oxygen_fraction(mix)
    return mix.o2 / (mix.o2 + mix.n2)
end

assert(left.o2 and left.n2 and right.o2 and right.n2, "neither vessel kept a pure gas")
near(oxygen_fraction(left), oxygen_fraction(right), 1e-9, "one mixture, both vessels")
near(oxygen_fraction(between), oxygen_fraction(right), 1e-9, "and the run between them")
near(oxygen_fraction(left), o2_0 / (o2_0 + n2_0), 1e-9, "the shift's own gas, stirred")

-- Per gas, because a total can hide a swap.
near(left.o2 + right.o2 + between.o2, o2_0, o2_0 * 1e-12, "the oxygen book")
near(left.n2 + right.n2 + between.n2, n2_0, n2_0 * 1e-12, "the nitrogen book")

local shared_kpa = pressure_of(o2_0 + n2_0, 2.0 * TANK_M3 + SHARED_M3, T20C)
near(t.tank_pressure(2, 1), shared_kpa, shared_kpa * 1e-9, "one pressure, both vessels")
near(t.tank_pressure(5, 1), shared_kpa, shared_kpa * 1e-9, "and the run between them")
near(t.pipe_pressure(3, 1), shared_kpa, shared_kpa * 1e-9, "on the same number")

-- ---------------------------------------------------------------
-- THE OTHER DIRECTION: AN EMPTY VESSEL ON A CHARGED MAIN.
--
-- Nothing about a tank is a supply: it is a hole in the plumbing with a
-- volume, so a run charged past it drains INTO it. Gauges cannot say
-- which way it went -- both ends converge either way -- so the direction
-- is read off the mole count, here and above.
-- ---------------------------------------------------------------
t.world([==[(
    name: "an empty vessel on a charged main",
    legend: { '.': (turf: Plating), '#': (turf: Wall) },
    rows: ["##############", "#............#", "##############"],
    spawns: [(1, 1)],
    structures: [(12, 1, "stationary_tank", "anchored")],
    pipes: [
        (2, 1, 4), (3, 1, 4), (4, 1, 4), (5, 1, 4), (6, 1, 4),
        (7, 1, 4), (8, 1, 4), (9, 1, 4), (10, 1, 4), (11, 1, 4),
    ],
)]==], 7)

t.join()
t.tick()

local MAIN_M3 = 10.0 * PIPE_M3 + PORT_M3
local main_0 = total(t.pipe_gas(2, 1))
local drained_kpa = pressure_of(main_0, MAIN_M3 + TANK_M3, T20C)
assert(t.tank_pressure(12, 1) == 0.0, "the vessel opens the shift empty")
assert(total(t.tank_gas(12, 1)) == 0.0, "with nothing in its book at all")
t.run_ticks(10)

local main_1 = total(t.pipe_gas(2, 1))
local vessel_1 = total(t.tank_gas(12, 1))
assert(vessel_1 > 0.0, "the vessel filled from the main")
near(main_0 - main_1, vessel_1, vessel_1 * 1e-9,
    "every mole in it came out of the run -- THE MAIN PAYS")
near(main_1 + vessel_1, main_0, main_0 * 1e-12, "with the book balancing")
near(t.tank_pressure(12, 1), drained_kpa, drained_kpa * 1e-9,
    "and both settle on the volume-weighted pressure, from below")
near(t.pipe_pressure(2, 1), drained_kpa, drained_kpa * 1e-9, "the main with it")
assert(t.pipe_pressure(2, 1) < 30.0,
    "ten lengths against 2500 L is a main with nothing left: "
        .. t.pipe_pressure(2, 1) .. " kPa")

-- ---------------------------------------------------------------
-- THE TORCH.
--
-- tg's `on_deconstruction` is one line -- `location.assume_air(
-- air_contents)` (tank.dm:433-436) -- and it is the only reason cutting a
-- vessel open is not where matter stops existing.
-- stationary_tank_build_test.luau proves the room's reading goes up; this
-- weighs it, sealed, in a gas nobody breathes.
-- ---------------------------------------------------------------
t.world([==[(
    name: "the torch",
    legend: { '.': (turf: Floor), '#': (turf: Wall) },
    rows: ["#####", "#...#", "#...#", "#...#", "#####"],
    spawns: [(2, 2)],
    items: [(2, 2, "welder")],
    structures: [(3, 2, "stationary_tank", "anchored", ("n2", 3000.0))],
)]==], 7)

local w = t.join()
t.tick()
-- Nine tiles of deck, each holding its own air: the room's book is nine.
local function room_nitrogen()
    local sum = 0.0
    for y = 1, 3 do
        for x = 1, 3 do
            sum = sum + ((t.room_gas(x, y) or {}).n2 or 0.0)
        end
    end
    return sum
end

local held = t.tank_gas(3, 2).n2
local room_0 = room_nitrogen()
assert(held > 3000.0, "a vessel with real weight in it: " .. held .. " mol")
t.click(w, 2, 2, t.target_at(2, 2, "welder"))
t.run_ticks(3)
t.click(w, 3, 2, t.target_at(3, 2))
t.run_seconds(4.5)

assert(t.tank_pressure(3, 2) == nil, "the vessel is gone")
near(room_nitrogen() - room_0, held, held * 1e-9,
    "every mole it held is on the deck: " .. held .. " mol")
-- The frame it leaves is LOOSE, and a loose thing standing in its own
-- vessel's decompression does not stay where it was put -- so look.
local frame = nil
for y = 1, 3 do
    for x = 1, 3 do
        local s = t.structure_at(x, y)
        frame = (s and s.id == "stationary_tank_frame") and s or frame
    end
end
assert(frame and frame.state == "displaced",
    "the re-platable frame is somewhere in the room: " .. tostring(frame and frame.state))
t.run_seconds(30)
near(room_nitrogen() - room_0, held, held * 1e-9,
    "and it is still there half a minute later, spread through the room")

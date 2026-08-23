-- The dial taken to both of its stops, and then changed in the middle
-- of the job it was set for.
--
-- thermomachine_test.luau proves the machine: it heats, it cools, it
-- arrests on the setpoint instead of running past it, and a switch or a
-- dead room circuit stops it dead -- every one of those scenarios dialled to a
-- comfortable number in the middle of the range. This file is about the
-- ENDS of that range and about changing one's mind, which are the two
-- things a cold room is actually built by.
--
-- What the stops are, and why they are those numbers, is
-- thermomachine.dm:95-96 read through two tier-1 micro-lasers:
--
--   min = max(T0C - (170 + lasers*15), TCMB) =  73.15 K
--   max = T20C + 140*lasers                  = 573.15 K
--
-- Both are honoured in two places at once, and this file checks both at
-- each stop: the PANEL publishes them (so no engineer can dial a number
-- the machine will refuse) and `set_device_temperature` clamps to the
-- same pair (so no client can send one either). A clamp that was only
-- cosmetic would pass every readout assertion in the world and still
-- drive the gas to 20 K, so each stop is asserted as a number on the
-- panel AND as the temperature the gas is actually held at.

local FLOOR = 73.15
local CEILING = 573.15
local T20C = 293.15
local SPAN = CEILING - FLOOR

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function readout(ui, label)
    for _, r in ipairs(ui.readouts) do
        if r.label == label then
            return r.value
        end
    end
    return nil
end

-- One atmos pass: SSair's cadence, and the unit works its port once per
-- pass. A spec that wants to watch the approach counts in these.
local function pass()
    t.run_ticks(10)
end

local function moles(x, y)
    local n = 0.0
    for _, amount in pairs(t.pipe_gas(x, y) or {}) do
        n = n + amount
    end
    return n
end

-- Where the needle should sit for a given setpoint: the dial's place in
-- its own range, which is what a window whose one number is a TARGET
-- rather than a measurement can honestly put across the top of itself.
local function needle(target)
    return (target - FLOOR) / SPAN * 100.0
end

-- A short run, a unit standing at the end of it, and an engineer under
-- the machine with their hands empty.
t.world([==[(
    name: "cold room",
    legend: {
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#......#",
        "#..a..g#",
        "########",
    ],
    spawns: [(3, 2)],
    pipes: [(1, 1, 4), (2, 1, 4)],
    structures: [(3, 1, "thermomachine")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==], 7)

local p = t.join()
t.tick()
t.click(p, 3, 1, t.target_at(3, 1, "thermomachine"))
t.tick()

local charged = moles(1, 1)
local opening_kpa = t.pipe_pressure(1, 1)
near(t.pipe_temperature(1, 1), T20C, 0.01, "the run opens at room temperature")
near(t.ui(p).gauge, needle(T20C), 1e-9, "and the needle opens at the default setpoint's place in the range")

-- ---------------------------------------------------------------
-- THE COLD STOP, ASKED FOR THE WAY A PANICKING ENGINEER ASKS.
--
-- The stop itself is a settable number rather than a limit you may
-- only approach -- and then a number well under it, zero, and two
-- numbers under absolute zero are all the same request, answered with
-- 73.15 K rather than with a refusal or a dead machine.
-- ---------------------------------------------------------------
t.ui_act(p, "set", '{"field":"temperature","value":73.15}')
t.tick()
near(t.ui(p).setpoints[1].value, FLOOR, 1e-12, "the stop itself is a settable number")

for _, asked in ipairs({ 20, 0, -40, -1000 }) do
    t.ui_act(p, "set", '{"field":"temperature","value":' .. asked .. "}")
    t.tick()
    near(t.ui(p).setpoints[1].value, FLOOR, 1e-9, asked .. " K is answered with the machine's floor")
end
near(t.ui(p).gauge, 0.0, 1e-9, "and the needle sits hard against the cold end")

-- ---------------------------------------------------------------
-- ALL THE WAY DOWN, AND A STOP THAT IS A STOP.
--
-- The clamp above is only a readout until the machine is asked to
-- honour it. Switched on at a dial that was ASKED for -1000 K, the gas
-- must come to rest at 73.15 and stay there: monotone the whole way
-- down, never a kelvin under the floor, no drift afterwards either
-- way. A machine that clamped its panel and not its arithmetic would
-- pass every assertion above and freeze this run solid.
-- ---------------------------------------------------------------
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(3, 1).state == "running", "the unit is running")

local previous = t.pipe_temperature(1, 1)
for n = 1, 10 do
    pass()
    local now = t.pipe_temperature(1, 1)
    assert(now <= previous + 1e-9, "pass " .. n .. " never runs backwards: " .. previous .. " -> " .. now)
    assert(now >= FLOOR - 1e-9, "and never dips under the floor: " .. now)
    previous = now
end
near(t.pipe_temperature(1, 1), FLOOR, 1e-6, "the descent arrests ON the stop")

-- Sampled again and again, long after it arrived. tg's pass computes
-- `delta = target - T` and returns on a zero, so a unit sitting on its
-- setpoint does nothing at all -- and "nothing" has to mean nothing,
-- not a hunt either side of the number.
local arrested = t.pipe_temperature(1, 1)
for n = 1, 10 do
    t.run_seconds(5)
    near(t.pipe_temperature(1, 1), arrested, 1e-9, "sample " .. n .. " has not moved a bit")
end

-- NOT ONE MOLE, and the pressure that fell is the gas law falling with
-- the temperature -- the same moles in the same volume, colder.
near(moles(1, 1), charged, charged * 1e-9, "no gas entered or left the run")
near(t.pipe_pressure(1, 1) / opening_kpa, FLOOR / T20C, 1e-6, "and the pressure fell in the ratio the temperature did")

-- ---------------------------------------------------------------
-- AND ALL THE WAY UP, OFF THE SAME DIAL.
--
-- The hot stop, asked for the same way, and then honoured the same
-- way. This is the assertion that the machine is a THERMOSTAT rather
-- than a refrigerator with a dial on it: the run it just froze to 73 K
-- is driven to 573 K by the same hardware and the same arithmetic,
-- with the sign of `target - T_port` the only thing that changed.
-- ---------------------------------------------------------------
for _, asked in ipairs({ 900, 5000 }) do
    t.ui_act(p, "set", '{"field":"temperature","value":' .. asked .. "}")
    t.tick()
    near(t.ui(p).setpoints[1].value, CEILING, 1e-9, asked .. " K is answered with the machine's ceiling")
end
near(t.ui(p).gauge, 100.0, 1e-9, "and the needle sits hard against the hot end")

previous = t.pipe_temperature(1, 1)
for n = 1, 10 do
    pass()
    local now = t.pipe_temperature(1, 1)
    assert(now >= previous - 1e-9, "pass " .. n .. " never runs backwards: " .. previous .. " -> " .. now)
    assert(now <= CEILING + 1e-9, "and never overshoots the ceiling: " .. now)
    previous = now
end
near(t.pipe_temperature(1, 1), CEILING, 1e-6, "the climb arrests ON the stop")

local topped = t.pipe_temperature(1, 1)
for n = 1, 10 do
    t.run_seconds(5)
    near(t.pipe_temperature(1, 1), topped, 1e-9, "hot sample " .. n .. " has not moved either")
end
near(moles(1, 1), charged, charged * 1e-9, "still not one mole in or out")
near(t.pipe_pressure(1, 1) / opening_kpa, CEILING / T20C, 1e-6, "and the pressure climbed in that ratio too")
near(
    tonumber(readout(t.ui(p), "pipe"):match("[%d%.]+")),
    t.pipe_temperature(1, 1),
    0.1,
    "with the panel's thermometer reading the run it is plumbed into"
)

-- ---------------------------------------------------------------
-- CHANGING ONE'S MIND IN THE MIDDLE OF THE JOB.
--
-- The run above is two lengths of pipe: a third of a cubic metre of
-- gas against a 5000 J/K thermostat, which closes 95% of the gap every
-- pass, so there is barely a middle to catch it in. A real cold room
-- has a RESERVOIR behind its mouth, and this bench is that -- a 2500 L
-- tank left open onto the run through a hand valve. The tank is not a
-- second machine and does nothing but hold gas (stationary_tank_test);
-- what it buys here is a ramp slow enough that an engineer can change
-- their mind halfway up it, which is the only way to ask what the
-- machine does when the dial moves UNDER the gas it is holding.
-- ---------------------------------------------------------------
t.world([==[(
    name: "freezer bay",
    legend: {
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "##########",
        "#........#",
        "#..a....g#",
        "##########",
    ],
    spawns: [(3, 2)],
    pipes: [(2, 1, 4), (4, 1, 4), (5, 1, 4)],
    structures: [
        (1, 1, "stationary_tank", "anchored", ("n2", 400.0)),
        (3, 1, "manual_valve"),
        (6, 1, "thermomachine"),
    ],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3), (7, 1, 3), (8, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3), (7, 2, 3), (8, 2, 3),
    ],
)]==], 7)

local e = t.join()
t.tick()
assert(t.structure_at(3, 1).state == "shut", "the hand valve opens the shift shut")

t.click(e, 3, 1, t.target_at(3, 1, "manual_valve"))
t.run_seconds(4)
assert(t.structure_at(3, 1).state == "open", "and an engineer opens it onto the line")
assert(t.pipe_pressure(5, 1) > 300.0, "which charges the run off the tank: " .. t.pipe_pressure(5, 1))

for _ = 1, 3 do
    t.move(e, "east")
    t.run_ticks(5)
end
t.click(e, 6, 1, t.target_at(6, 1, "thermomachine"))
t.tick()
assert(t.ui(e), "the unit at the far end of the line answers an empty hand")

t.ui_act(e, "set", '{"field":"temperature","value":573.15}')
t.ui_act(e, "toggle", '{"field":"power"}')
t.run_ticks(2)
near(t.ui(e).setpoints[1].value, CEILING, 1e-9, "dialled to the top")
near(t.ui(e).gauge, 100.0, 1e-9, "and the needle says so")

for _ = 1, 10 do
    pass()
end
local caught = t.pipe_temperature(5, 1)
assert(caught > T20C + 40.0, "ten passes in, the line is well up: " .. caught)
assert(caught < CEILING - 20.0, "and still well short of the target it was given: " .. caught)
assert(readout(t.ui(e), "pipe"):find("K", 1, true), "the panel is reading the line all the way up")

-- The dial goes UNDER the gas. tg's pass takes `target - T_port` fresh
-- every time and has no memory of which way it was working last, so
-- there is no ramp to unwind and no state to flush: the very next pass
-- is a cooling pass.
t.ui_act(e, "set", '{"field":"temperature","value":250}')
t.run_ticks(2)
near(t.ui(e).setpoints[1].value, 250.0, 1e-9, "the thermostat takes the new number")
near(t.ui(e).gauge, needle(250.0), 1e-9, "and the needle walks back down the range with it")

pass()
local turned = t.pipe_temperature(5, 1)
assert(turned < caught - 20.0, "and it turned round on the very next pass: " .. caught .. " -> " .. turned)

previous = turned
for n = 1, 10 do
    pass()
    local now = t.pipe_temperature(5, 1)
    assert(now <= previous + 1e-9, "the descent is monotone too, pass " .. n .. ": " .. now)
    assert(now >= 250.0 - 1e-9, "and it does not undershoot the new target: " .. now)
    previous = now
end

-- ...and once more, back the other way, before it ever arrives. Three
-- settings in one job, and the panel tracked every one of them.
local mid = t.pipe_temperature(5, 1)
assert(mid > 250.0 + 5.0, "still on its way down when the dial moves again: " .. mid)
t.ui_act(e, "set", '{"field":"temperature","value":300}')
t.run_ticks(2)
near(t.ui(e).setpoints[1].value, 300.0, 1e-9, "the third setting of the shift")
near(t.ui(e).gauge, needle(300.0), 1e-9, "with the needle back up the range")

pass()
assert(
    t.pipe_temperature(5, 1) > mid,
    "and it is heating again, never switched off and on: " .. mid .. " -> " .. t.pipe_temperature(5, 1)
)

t.run_seconds(90)
near(t.pipe_temperature(5, 1), 300.0, 0.01, "the line settles on the last number it was given")
t.run_seconds(30)
near(t.pipe_temperature(5, 1), 300.0, 0.01, "and holds it, with the reservoir behind it holding too")

-- What the panel says while the machine works, and what it says when
-- the station stops paying for it.
--
-- thermomachine_test.luau asks a unit that never had power what it
-- does: nothing, and its panel says "dead". That is the easy half of
-- tg's `on && is_operational`, because a machine that was never fed has
-- nothing to lose. This file is the other half -- a unit that IS fed,
-- IS working, and is halfway through a job when the breaker goes.
--
-- Two things are asserted across that moment and neither is about gas.
--
-- The first is the PANEL AS AN INSTRUMENT. This window is the only one
-- in the atmospherics kit whose readout is a thermometer rather than a
-- pressure (sim/ui/settings/thermo.rs), and its `pipe` row carries a
-- tone that says which SIDE of the dial the gas is on: under it, over
-- it, or on it. That is the whole of "which way is this machine
-- working" for somebody standing in front of it, and it is a fact about
-- the setpoint and the gas together -- so it moves when either does,
-- including when the engineer moves the dial under gas that is already
-- hot.
--
-- The second is that a THERMOSTAT IS NOT A MEMORY. The dial, the
-- switch and the position the gas was left in have to survive a
-- blackout untouched, because a machine that forgot its setting when
-- the lights went out would be one that quietly reverts a cold room to
-- room temperature the moment the shift's first power fault clears.

local T20C = 293.15

-- A document's words are labels: `{id=…}` for one the engine names,
-- `{text=…}` for one content wrote (docs/tgui/labels.md).
local function word(label)
    if type(label) ~= "table" then return label end
    return label.id or label.text
end

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function row(ui, label)
    for _, r in ipairs(ui.readouts) do
        if word(r.label) == label then
            return r
        end
    end
    return nil
end

local function pass()
    t.run_ticks(10)
end

-- A wired department in miniature, the same shape device_power_test
-- uses: a generator and an APC in the west corner, a branch circuit
-- running east and up under the machine's own tile, and the unit
-- standing at the end of a short run. Every powered atmospherics device
-- takes its supply from the branch under its own tile (tg's
-- AREA_USAGE_EQUIP), so this is the wiring that makes "fed" a fact
-- about a graph rather than about a default.
t.world([==[(
    name: "freezer bench",
    legend: {
        '.': (turf: Plating),
        '#': (turf: Wall),
        'g': (turf: Plating, fixture: Some(Generator)),
        'a': (turf: Plating, fixture: Some(Apc)),
    },
    rows: [
        "############",
        "#..........#",
        "#ga........#",
        "############",
    ],
    spawns: [(5, 2)],
    pipes: [(3, 1, 4), (4, 1, 4)],
    structures: [(5, 1, "thermomachine")],
    cables: [
        (1, 2, 2), (2, 2, 3),
        (3, 2, 1), (4, 2, 1), (4, 1, 1), (5, 1, 1),
    ],
)]==], 7)

local p = t.join()
t.tick()
t.run_seconds(3) -- the electrical pass is 0.5 Hz; let one land

assert(t.structure_at(5, 1).id == "thermomachine", "a unit stands on the bench")
assert(t.structure_at(5, 1).state == "off", "switched off out of the crate")
assert(t.apc_at(2, 2).equipment == true, "with the bench's APC feeding its circuit")
assert(t.segment_at(5, 1).feed == 1, "which reaches the machine's own tile")

t.click(p, 5, 1, t.target_at(5, 1, "thermomachine"))
t.tick()
assert(t.ui(p), "the unit answers an empty hand with its panel")

-- ---------------------------------------------------------------
-- THE TONE IS A SENTENCE ABOUT TWO NUMBERS.
--
-- Out of the crate the dial is at T20C and so is the run, so the panel
-- says neither: the gas is ON the setpoint, and a machine sitting on
-- its setpoint is idle for a reason of its own rather than stopped.
-- ---------------------------------------------------------------
near(t.ui(p).setpoints[1].value, T20C, 0.01, "the thermostat opens at tg's T20C")
near(t.pipe_temperature(3, 1), T20C, 0.5, "and the run opens there too")
assert(row(t.ui(p), "thermo.pipe").tone == "idle", "so the panel says the gas is on the dial")
assert(row(t.ui(p), "thermo.supply").value.id == "thermo.supply.fed", "and that the mains are behind it")

-- Dial well above the gas and the tone flips before a single joule
-- moves: this is the setpoint's side of the comparison changing, not
-- the machine's.
t.ui_act(p, "set", '{"field":"temperature","value":500}')
t.tick()
assert(row(t.ui(p), "thermo.pipe").tone == "off", "the gas is under the dial, and the panel says so")
near(t.pipe_temperature(3, 1), T20C, 0.5, "with nothing switched on and nothing moved")

t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(5, 1).state == "running", "now it is running")

pass()
local climbed = t.pipe_temperature(3, 1)
assert(climbed > T20C + 100.0, "and one pass takes this short run most of the way: " .. climbed)
assert(climbed < 500.0 - 5.0, "though not all of it -- the job is not finished: " .. climbed)
assert(row(t.ui(p), "thermo.pipe").tone == "off", "so the gas is still under the dial")

-- ...and now the dial goes UNDER the gas, which is the third tone and
-- the one that only a machine that heats AND cools can ever show.
t.ui_act(p, "set", '{"field":"temperature","value":300}')
t.tick()
assert(row(t.ui(p), "thermo.pipe").tone == "on", "the gas is over the dial now, and only the dial moved")
near(t.ui(p).gauge, (300.0 - 73.15) / 500.0 * 100.0, 1e-9, "with the needle at the new setting's place")

-- ---------------------------------------------------------------
-- AND THE STATION STOPS PAYING, MID-JOB.
--
-- The breaker trips with a hundred and eighty kelvin of work still in
-- front of the machine. tg gates the pass on `on && is_operational`
-- (thermomachine.dm:172-174) and draws the picture from the same
-- question, so all three of the switch, the sprite and the gas have to
-- agree in the same tick -- and the ONE of them that must not change is
-- the switch, because nobody threw it.
-- ---------------------------------------------------------------
local caught_k = t.pipe_temperature(3, 1)
local caught_j = t.pipe_energy(3, 1)
assert(caught_k > 300.0 + 100.0, "there is a real job in front of it: " .. caught_k .. " K, dialled to 300")

t.outage()
t.run_seconds(3)

assert(t.ledger_has("PowerOutage"), "the fault is on the record")
assert(t.apc_at(2, 2).equipment == false, "the APC has nothing to hand the equipment channel")
assert(t.segment_at(5, 1).l1 ~= nil, "the cable under the machine is still cable")
assert(t.segment_at(5, 1).feed == nil, "but nothing on it is carrying")
assert(
    t.structure_at(5, 1).state == "off",
    "and the unit is drawn stopped, which is `on && is_operational` picking the picture"
)
assert(t.ui(p).toggles[1].on == true, "while the switch is exactly where the engineer left it")
assert(row(t.ui(p), "thermo.supply").value.id == "thermo.supply.dead", "the panel says which of the two it is")
near(t.ui(p).setpoints[1].value, 300.0, 1e-9, "and the thermostat kept its setting through the fault")

-- The gas is left standing precisely where the last fed pass put it.
-- Not "roughly": an unpowered thermomachine is not a slow one, and a
-- run coasting a tenth of a kelvin a minute would be a machine still
-- quietly drawing.
for n = 1, 6 do
    t.run_seconds(10)
    near(t.pipe_temperature(3, 1), caught_k, 1e-9, "sample " .. n .. ": the gas has not moved")
    near(t.pipe_energy(3, 1), caught_j, 1e-6, "and neither has its joule book")
end
assert(
    t.pipe_temperature(3, 1) > 300.0 + 100.0,
    "the job it was doing is still sitting there untouched: " .. t.pipe_temperature(3, 1)
)

-- A dead machine takes orders perfectly happily -- the panel is fed by
-- the click that opened it and by nothing else. What it must not do is
-- act on them.
t.ui_act(p, "set", '{"field":"temperature","value":73.15}')
t.run_ticks(2)
near(t.ui(p).setpoints[1].value, 73.15, 1e-9, "the dial goes to the stop while the grid is dark")
near(t.ui(p).gauge, 0.0, 1e-9, "and the needle with it")
assert(row(t.ui(p), "thermo.pipe").tone == "on", "the tone still reads the two numbers it is given")
t.run_seconds(30)
near(t.pipe_temperature(3, 1), caught_k, 1e-9, "and not one joule followed the order")

-- The switch survives being thrown while dead, too: off is a position
-- somebody chose, and a machine that came back up on its own would be
-- one that ignored the last hand on it.
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.ui(p).toggles[1].on == false, "the switch went over on a dead grid")
assert(t.structure_at(5, 1).state == "off", "and the picture is the same either way, which is the point")
t.run_seconds(20)
near(t.pipe_temperature(3, 1), caught_k, 1e-9, "with the gas still exactly where the blackout left it")

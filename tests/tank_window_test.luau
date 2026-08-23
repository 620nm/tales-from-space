-- The bottle on your back has a window, and it is the same window the
-- canister and the bolted-in reservoir wear.
--
-- What is inside a vessel is one module (sim/ui/modules/vessel.rs) --
-- a row per gas, a pressure, a temperature, a size -- so a diver
-- reading his tank and an engineer reading a canister are reading the
-- same instrument. What this one adds is tg's own control: the release
-- valve a breath is drawn at (`ui_act`'s "pressure",
-- code/game/objects/items/tanks/tanks.dm:261-281), clamped into tg's
-- 0..3 atmospheres.
--
-- The gesture is the activate-in-hand key, which also works the valve:
-- tg splits the two across an action button and a right-click, and we
-- have one key, so handling your bottle opens it and shows you it.

t.world([==[(
    name: "the locker room",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    items: [(2, 1, "oxygen_tank")],
)]==], 7)

local p = t.join()
t.tick()

local function readout(ui, label)
    for _, r in ipairs(ui.readouts) do
        if r.label == label then
            return r
        end
    end
    return nil
end

local function setpoint(ui, field)
    for _, s in ipairs(ui.setpoints) do
        if s.field == field then
            return s
        end
    end
    return nil
end

local function number(ui, label)
    local row = readout(ui, label)
    return row and tonumber(string.match(row.value, "[%d%.]+")) or nil
end

-- ---------------------------------------------------------------
-- INTO A HAND, AND THE KEY. A bottle on the deck is a bottle you pick
-- up; the panel is what the in-hand key opens.
-- ---------------------------------------------------------------
-- The pack comes off first and stays off: a job's kit is already
-- wearing the slot this bottle wants, and the last section of this
-- spec puts the bottle there.
t.unequip(p, "back")
t.run_ticks(5)
t.drop(p)
t.run_ticks(5)

t.click(p, 2, 1, t.target_at(2, 1, "oxygen_tank"))
t.run_ticks(2)
assert(t.hands(p).held == "oxygen_tank", "the bottle is in hand")
assert(t.ui(p) == nil, "picking a thing up opens nothing")

t.use_self(p)
t.run_ticks(2)
local ui = t.ui(p)
assert(ui, "the in-hand key opens the panel")
assert(ui.native == "settings", "the shared panel: " .. tostring(ui.native))
assert(ui.kind == "held_tank", "kind: " .. tostring(ui.kind))
assert(#ui.toggles == 0, "the valve is a KEY, not a button on the panel")

-- ---------------------------------------------------------------
-- WHAT IS IN IT. The shared vessel module: a row per gas present, and
-- the three numbers every vessel has.
-- ---------------------------------------------------------------
assert(readout(ui, "oxygen"), "one row PER GAS PRESENT, named by the gas")
assert(readout(ui, "oxygen").section == "contents", "under the module's heading")
assert(readout(ui, "nitrogen") == nil, "and no row for a gas that is not in there")
local kpa = number(ui, "pressure")
assert(math.abs(kpa - 6 * 101.325) < 5.0,
    "charged to the six atmospheres its file says: " .. tostring(kpa))
assert(number(ui, "temperature") > 200.0, "a temperature")
assert(math.abs(number(ui, "volume") - 70.0) < 0.001,
    "and tg's TANK_STANDARD_VOLUME, in litres: " .. tostring(number(ui, "volume")))
assert(readout(ui, "supply") == nil, "an ordinary bottle is not inexhaustible")
assert(ui.gauge == nil, "and nothing wrote a rating on the side of it")
assert(readout(ui, "valve").value == "connected", "the key opened the valve too")

-- ---------------------------------------------------------------
-- THE ONE KNOB. tg's release pressure, tg's bounds, and the clamp is
-- the server's -- a client can dial anything it likes and gets the
-- range back.
-- ---------------------------------------------------------------
local dial = setpoint(ui, "release")
assert(dial, "the release valve is a dial")
assert(math.abs(dial.value - 16.0) < 0.001, "at tg's default: " .. tostring(dial.value))
assert(dial.min == 0.0, "tg's TANK_MIN_RELEASE_PRESSURE")
assert(math.abs(dial.max - 3 * 101.325) < 0.001, "and tg's maximum, three atmospheres")

t.ui_act(p, "set", '{"field":"release","value":30}')
t.tick()
assert(math.abs(setpoint(t.ui(p), "release").value - 30.0) < 0.001, "the valve took 30 kPa")
t.ui_act(p, "set", '{"field":"release","value":9000}')
t.tick()
assert(math.abs(setpoint(t.ui(p), "release").value - 3 * 101.325) < 0.001,
    "and a client cannot dial past three atmospheres")
t.ui_act(p, "set", '{"field":"release","value":"min"}')
t.tick()
assert(setpoint(t.ui(p), "release").value == 0.0, "nor below nothing")
assert(t.ledger_has("MachineSetpoint"), "and every setting is on the record")

-- Nothing else on this panel is a control, so nothing else answers.
t.ui_act(p, "toggle", '{"field":"valve"}')
t.ui_act(p, "set", '{"field":"pressure","value":500}')
t.tick()
assert(setpoint(t.ui(p), "release").value == 0.0, "a field the panel never offered moves nothing")

-- ---------------------------------------------------------------
-- AND IT STAYS OPEN ON YOUR BACK. A panel on your own kit has no
-- distance to lose -- the tank feeds your lungs from a worn slot
-- exactly as it does from your hand -- so putting it on does not
-- close its window.
-- ---------------------------------------------------------------
t.equip(p)
t.run_ticks(30)
assert(t.worn(p).back == "oxygen_tank", "the bottle is on the back now")
assert(t.hands(p)[1] == nil and t.hands(p)[2] == nil, "and out of both hands")
local worn = t.ui(p)
assert(worn and worn.kind == "held_tank", "its panel is still up")
assert(readout(worn, "oxygen"), "and still reading the bottle")

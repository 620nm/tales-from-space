-- The bottle on your back has a window, and it is the same window the
-- canister and the bolted-in reservoir wear.
--
-- What is inside a vessel is one typed block (docs/tgui/matter-block.md)
-- -- a row per substance, in the state it is in, over the shell and the
-- warmth -- so a diver reading his tank and an engineer reading a
-- canister are reading the same instrument. What this one adds is tg's
-- own control: the release valve a breath is drawn at (`ui_act`'s
-- "pressure", code/game/objects/items/tanks/tanks.dm:261-281), clamped
-- into tg's 0..3 atmospheres.
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

-- A document's words are labels: `{id=…}` for one the engine names,
-- `{text=…}` for one content wrote (docs/tgui/labels.md).
local function word(label)
    if type(label) ~= "table" then return label end
    return label.id or label.text
end

local function readout(ui, label)
    for _, r in ipairs(ui.readouts) do
        if word(r.label) == label then
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

-- The contents block: what the vessel is HOLDING, by state, in the
-- units each state is read in (docs/tgui/matter-block.md).
local function block(ui, section)
    for _, b in ipairs(ui.matter or {}) do
        if word(b.section) == section then
            return b
        end
    end
    return nil
end

local function state(b, phase)
    for _, s in ipairs(b and b.states or {}) do
        if s.phase == phase then
            return s
        end
    end
    return nil
end

local function named(st, name)
    for _, r in ipairs(st and st.rows or {}) do
        if r.name == name then
            return r
        end
    end
    return nil
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
assert(ui.document == "modules" and ui.presentation == "modules",
    "the shared module document")
assert(#ui.toggles == 0, "the valve is a KEY, not a button on the panel")

-- ---------------------------------------------------------------
-- WHAT IS IN IT. The shared contents block: a row per substance
-- present, in the state it is in, and the numbers every vessel has.
-- ---------------------------------------------------------------
local contents = block(ui, "holder.contents")
assert(contents, "the vessel's block, under the module's heading")
local gas = state(contents, "gas")
assert(gas, "a bottle of oxygen holds a gas")
assert(named(gas, "oxygen"), "one row PER SUBSTANCE PRESENT, named by the substance")
assert(named(gas, "nitrogen") == nil, "and no row for one that is not in there")
assert(math.abs(gas.measure - 6 * 101.325) < 5.0,
    "charged to the six atmospheres its file says: " .. tostring(gas.measure))
assert(contents.temperature_k > 200.0, "a temperature")
assert(math.abs(contents.volume_l - 70.0) < 0.001,
    "and tg's TANK_STANDARD_VOLUME, in litres: " .. tostring(contents.volume_l))
assert(contents.sealed == true, "a bottle has a lid")
assert(readout(ui, "holder.supply") == nil, "an ordinary bottle is not inexhaustible")
assert(readout(ui, "holder.rating") == nil, "and nothing wrote a rating on the side of it")
assert(ui.gauge == nil, "so there is no needle to draw against one")
assert(readout(ui, "tank.internals").value.id == "tank.internals.connected", "the key opened the valve too")

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
assert(worn and worn.document == "modules" and worn.presentation == "modules",
    "its document is still up")
assert(named(state(block(worn, "holder.contents"), "gas"), "oxygen"),
    "and still reading the bottle")

-- The two panels the grid wears, from the other side of the glass.
--
-- An APC and a power storage unit are the same window with different
-- words: a store, whatever knobs the machine has of its own, and a
-- block per cable layer that actually runs under it. Neither is a
-- document of its own any more -- both are the settings panel every
-- machine with rows on it shares (docs/TGUI.md), assembled from
-- modules -- so this spec asks both of them the same questions and
-- expects the same shapes back.
--
-- The load-bearing half is the PORTS. Turning a bridge's port round is
-- the most consequential thing either panel does -- a bank told to
-- take from the backbone instead of feeding it puts a station in the
-- dark without anyone touching a breaker -- so what a client may name
-- is exactly what the window in front of it published, and a layer
-- with no cable under the machine published nothing.

-- The panel at (1, 2) stands on the room circuit AND the backbone that
-- comes down from the generator. The bank at (4, 1) stands on the
-- backbone alone, which is what makes its window offer one port and
-- refuse the other two.
local ui_controls = require("@helpers/ui_controls")

t.world(
    [==[(
    name: "power windows",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
        'S': (composition: (components: [(component: "station_base")])),
        'a': (composition: (components: [(component: "station_base")])),
        'o': (composition: (components: [(component: "station_base")]), fixture: Some(Outlet)),
        'l': (composition: (components: [(component: "station_base")]), fixture: Some(Light)),
    },
    rows: [
        "########",
        "#G..S..#",
        "#a...ol#",
        "########",
    ],
    structures: [(2, 2, "player_spawn"), (4, 1, "smes"), (1, 2, "apc")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
    ],
    labels: [(1, 2, "Engineering")],
)]==],
    7
)

local p = t.join()
t.tick()
t.run_seconds(3) -- the electrical pass is 0.5 Hz; let one land

-- A document's words are labels: `{id=…}` for one the engine names,
-- `{text=…}` for one content wrote (docs/tgui/labels.md).
local word = ui_controls.word

local function readout(ui: unknown, label: string)
    for _, r in ipairs(ui_controls.rows(ui_controls.record(ui).readouts)) do
        if word(r.label) == label then
            return r
        end
    end
    error("missing expected panel row")
end

local function toggle(ui: unknown, field: string, option: string?): ui_controls.Record?
    for _, tog in ipairs(ui_controls.rows(ui_controls.record(ui).toggles)) do
        if tog.field == field and tog.option == option then
            return tog
        end
    end
    return nil
end

local function setpoint(ui: unknown, field: string)
    for _, s in ipairs(ui_controls.rows(ui_controls.record(ui).setpoints)) do
        if s.field == field then
            return s
        end
    end
    error("missing expected panel row")
end

local function walk(dir)
    t.move(p, dir)
    t.run_ticks(5)
end

-- ---------------------------------------------------------------
-- THE AREA PANEL. Three modules: the cell it keeps, the class gates
-- only it has, and a block for each of the two lines under it.
-- ---------------------------------------------------------------
t.click(p, 1, 2, t.target_at(p, 1, 2))
t.tick()
local apc = ui_controls.state(p)
assert(apc, "clicking the panel opens its window")
assert(
    apc.document == "modules" and apc.presentation == "modules",
    "the shared module document, not a device-specific kind"
)

assert(word(readout(apc, "store.stored").section) == "store.store", "the store is a module")
assert(word(readout(apc, "store.capacity").value) == "1.00 MJ", "tg's 1 MJ cell")
assert(ui_controls.number(apc.gauge) > 0.0, "and the gauge reads it")
-- A class row's label is the network's own word for it (content/compositions.luau).
for _, class in ipairs({ "equipment", "lighting", "environment" }) do
    assert(word(readout(apc, class).section) == "gates.gates", class .. " is a gated class")
    assert(word(readout(apc, class).value) == "gates.class.fed", "a fed panel sheds nothing")
end
assert(assert(t.structure_at(1, 2)).vars["lunatic/tfs:power_alarm"] == nil, "and calls no alarm")
assert(#ui_controls.rows(apc.setpoints) == 0, "an APC has no dial: the ladder is the pack's")

-- The master breaker is the one switch over the three classes that the
-- ladder does not own -- so it IS a control, unlike the classes
-- themselves, and it takes the room with it.
local function delivering(class: string): boolean
    return assert(assert(t.store_at(1, 2)).delivering)[class] == true
end
local TUBE = assert(t.light_at(6, 2)).color
assert(assert(toggle(apc, "master")).on, "the main breaker ships closed")
assert(
    word(assert(toggle(apc, "master")).section) == "gates.gates",
    "beside the lamps it gates"
)
ui_controls.toggle(p, "master")
t.run_seconds(3)
assert(assert(t.store_at(1, 2)).master == false, "the breaker opened")
assert(not assert(toggle(t.ui(p), "master")).on, "and the panel says so")
assert(not delivering("lighting"), "a panel with its breaker open feeds nothing")
local lamp = assert(t.light_at(6, 2))
assert(lamp.color == "#FF3232", "so its room drops to the fittings' own red cells on a full panel")
assert(t.ledger_has("DeliveryGateSet"), "throwing it is on the record")
ui_controls.toggle(p, "master")
t.run_seconds(3)
lamp = assert(t.light_at(6, 2))
assert(assert(t.store_at(1, 2)).master == true, "the breaker closed")
assert(lamp.lit and lamp.color == TUBE, "and closing it brings the room back: " .. lamp.color)
-- Both throws are the master's -- a row naming no class -- and the
-- crewman's who pressed it, not the ladder's.
local presser = assert(t.ledger_rows("joined_job")[1], "the join is on the record").actor
assert(presser.kind == "player", "the join row names the crewman")
local thrown = t.ledger_rows("DeliveryGateSet")
assert(#thrown == 2, "two throws, open then closed: " .. #thrown)
for index, row in ipairs(thrown) do
    assert(row.class == nil, "throw " .. index .. " is the master: " .. tostring(row.class))
    assert(row.on == (index == 2), "throw " .. index .. " opened, then closed")
    local by = row.actor
    assert(by.kind == "player" and by.id == presser.id, "throw " .. index .. " is the presser's: " .. by.kind)
end

assert(
    assert(toggle(apc, "ports.mode", "l1:output")).on,
    "L1 feeds the room"
)
assert(
    word(assert(toggle(apc, "ports.mode", "l1:output")).section) == "l1",
    "under its own heading"
)
assert(assert(toggle(apc, "ports.mode", "l2:input")).on, "L2 is where it takes from")
assert(toggle(apc, "ports.mode", "l3:output") == nil, "and there is no blue main under it")
assert(word(readout(apc, "ports.out").value):find("W", 1, true), "a port says what it carried")

-- The one control the panel publishes answers, and lands on the record.
ui_controls.toggle(p, "ports.mode", "l1:bidirectional")
t.tick()
assert(
    assert(assert(t.ports_at(1, 2, "power")).channels["l1"]).mode == "bidirectional",
    "the port turned round"
)
assert(assert(toggle(t.ui(p), "ports.mode", "l1:bidirectional")).on, "and the panel says so")
assert(t.ledger_has("MachineToggled"), "turning a port is on the record")
ui_controls.toggle(p, "ports.mode", "l1:output")
t.run_seconds(3)
assert(t.lit(6, 2), "the room circuit is feeding its lamp again")

-- ---------------------------------------------------------------
-- A load class is not a switch on this panel and a
-- port on a layer with no cable is not a control at all -- the window
-- in front of the player IS the whitelist, so neither is refused
-- politely, they are simply not there.
-- ---------------------------------------------------------------
assert(ui_controls.find(p, "/toggle/equipment/switch") == nil, "unoffered control is absent")
assert(ui_controls.find(p, "/toggle/lighting/switch") == nil, "unoffered control is absent")
t.tick()
assert(delivering("equipment"), "a class nobody offered stays where it was")
assert(delivering("lighting"), "both of them")

assert(ui_controls.find(p, "/toggle/ports.mode/l3:input") == nil, "unoffered control is absent")
assert(ui_controls.find(p, "/toggle/ports.mode/l1:sideways") == nil, "unoffered control is absent")
t.tick()
assert(assert(t.ports_at(1, 2, "power")).channels["l3"] == nil, "there is no third port to have moved")
assert(assert(assert(t.ports_at(1, 2, "power")).channels["l1"]).mode == "output", "and no mode nobody named")

-- ---------------------------------------------------------------
-- THE BANK. The same store module, its own two breakers and two
-- throttles, and ONE port -- because one line runs under it.
-- ---------------------------------------------------------------
walk("east")
walk("east")
t.click(p, 4, 1, t.target_at(p, 4, 1))
t.tick()
local smes = ui_controls.state(p)
assert(smes, "clicking the bank opens its window")
assert(smes.document == "modules" and smes.presentation == "modules", "the same module document")
assert(word(readout(smes, "store.stored").section) == "store.store", "the same store module")
assert(word(readout(smes, "store.capacity").value) == "5.00 MJ", "five standard cells")
assert(assert(toggle(smes, "input_breaker")).on, "both breakers closed out of the box")
assert(assert(toggle(smes, "output_breaker")).on)
assert(setpoint(smes, "input_w").max == 200000.0, "tg's 200 kW rate")
assert(setpoint(smes, "output_w").value == 200000.0, "and both dials wide open")
assert(assert(toggle(smes, "ports.mode", "l2:input")).on, "it takes from the backbone")
assert(toggle(smes, "ports.mode", "l1:output") == nil, "and stands on no other line")

-- The four things it does, in the framework's two verbs.
ui_controls.set(p, "output_w", "min")
t.tick()
assert(setpoint(t.ui(p), "output_w").value == 0.0, "the throttle went to nothing")
ui_controls.set(p, "output_w", 1e+30)
t.tick()
assert(
    setpoint(t.ui(p), "output_w").value == 200000.0,
    "and a client cannot dial past the unit's rate"
)
ui_controls.toggle(p, "output_breaker")
t.tick()
assert(not assert(toggle(t.ui(p), "output_breaker")).on, "the breaker opened")
assert(
    word(readout(t.ui(p), "throttles.output").value) == "throttles.line.breaker_open",
    "and the lamp says so"
)
assert(t.ledger_has("MachineSetpoint"), "re-dialling a throttle is on the record")

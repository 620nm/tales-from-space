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

t.world([==[(
    name: "power windows",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'G': (turf: Plating, fixture: Some(Generator)),
        'S': (turf: Plating, fixture: Some(Smes)),
        'a': (turf: Plating, fixture: Some(Apc)),
        'o': (turf: Plating, fixture: Some(Outlet)),
        'l': (turf: Plating, fixture: Some(Light)),
    },
    rows: [
        "########",
        "#G..S..#",
        "#a...ol#",
        "########",
    ],
    structures: [(2, 2, "player_spawn")],
    cables: [
        (1, 1, 2), (2, 1, 2), (3, 1, 2), (4, 1, 2), (1, 2, 2),
        (1, 2, 1), (2, 2, 1), (3, 2, 1), (4, 2, 1), (5, 2, 1), (6, 2, 1),
    ],
    labels: [(1, 2, "Engineering")],
)]==], 7)

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
-- THE AREA PANEL. Three modules: the cell it keeps, the channels only
-- it has, and a block for each of the two lines under it.
-- ---------------------------------------------------------------
t.click(p, 1, 2, t.target_at(p, 1, 2))
t.tick()
local apc = ui_controls.state(p)
assert(apc, "clicking the panel opens its window")
assert(apc.document == "modules" and apc.presentation == "modules",
    "the shared module document, not a device-specific kind")

assert(word(readout(apc, "battery.stored").section) == "battery.battery", "the store is a module")
assert(word(readout(apc, "battery.capacity").value) == "1.00 MJ", "tg's 1 MJ cell")
assert(ui_controls.number(apc.gauge) > 0.0, "and the gauge reads it")
for _, channel in ipairs({ "channels.equipment", "channels.lighting", "channels.environment" }) do
    assert(word(readout(apc, channel).section) == "channels.channels", channel .. " is a channel")
    assert(word(readout(apc, channel).value) == "channels.channel.fed", "a fed panel sheds nothing")
end
assert(word(readout(apc, "channels.alarm").value) == "channels.alarm.clear", "and calls no alarm")
assert(#ui_controls.rows(apc.setpoints) == 0, "an APC has no dial: the ladder is the pass's")

-- The master breaker is the one switch over the three channels that the
-- ladder does not own -- so it IS a control, unlike the channels
-- themselves, and it takes the room with it.
assert(assert(toggle(apc, "breaker")).on, "the main breaker ships closed")
assert(word(assert(toggle(apc, "breaker")).section) == "channels.channels", "beside the lamps it gates")
ui_controls.toggle(p, "breaker")
t.run_seconds(3)
assert(not assert(t.apc_at(1, 2)).operating, "the breaker opened")
assert(not assert(toggle(t.ui(p), "breaker")).on, "and the panel says so")
assert(not assert(t.apc_at(1, 2)).lighting, "a panel that is not operating feeds nothing")
assert(not t.lit(6, 2), "so its room is dark on a full cell")
assert(t.ledger_has("MachineToggled"), "throwing it is on the record")
ui_controls.toggle(p, "breaker")
t.run_seconds(3)
assert(assert(t.apc_at(1, 2)).operating and t.lit(6, 2), "and closing it brings the room back")

assert(assert(toggle(apc, "l1", "output")).on, "L1 feeds the room")
assert(word(assert(toggle(apc, "l1", "output")).section) == "ports.l1", "under its own heading")
assert(assert(toggle(apc, "l2", "input")).on, "L2 is where it takes from")
assert(toggle(apc, "l3", "output") == nil, "and there is no blue main under it")
assert(word(readout(apc, "ports.out").value):find("W", 1, true), "a port says what it carried")

-- The one control the panel publishes answers, and lands on the record.
ui_controls.toggle(p, "l1", "bidirectional")
t.tick()
assert(assert(assert(t.ports_at(1, 2)).l1).mode == "bidirectional", "the port turned round")
assert(assert(toggle(t.ui(p), "l1", "bidirectional")).on, "and the panel says so")
assert(t.ledger_has("MachineToggled"), "turning a port is on the record")
ui_controls.toggle(p, "l1", "output")
t.run_seconds(3)
assert(t.lit(6, 2), "the room circuit is feeding its lamp again")

-- ---------------------------------------------------------------
-- A channel is not a switch on this panel and a
-- port on a layer with no cable is not a control at all -- the window
-- in front of the player IS the whitelist, so neither is refused
-- politely, they are simply not there.
-- ---------------------------------------------------------------
assert(ui_controls.find(p, "/toggle/equipment/switch") == nil, "unoffered control is absent")
assert(ui_controls.find(p, "/toggle/lighting/switch") == nil, "unoffered control is absent")
t.tick()
assert(assert(t.apc_at(1, 2)).equipment, "a channel nobody offered stays where it was")
assert(assert(t.apc_at(1, 2)).lighting, "both of them")

assert(ui_controls.find(p, "/toggle/l3/input") == nil, "unoffered control is absent")
assert(ui_controls.find(p, "/toggle/l1/sideways") == nil, "unoffered control is absent")
t.tick()
assert(assert(t.ports_at(1, 2)).l3 == nil, "there is no third port to have moved")
assert(assert(assert(t.ports_at(1, 2)).l1).mode == "output", "and no mode nobody named")

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
assert(smes.document == "modules" and smes.presentation == "modules",
    "the same module document")
assert(word(readout(smes, "battery.stored").section) == "battery.battery", "the same store module")
assert(word(readout(smes, "battery.capacity").value) == "5.00 MJ", "five standard cells")
assert(assert(toggle(smes, "input_breaker")).on, "both breakers closed out of the box")
assert(assert(toggle(smes, "output_breaker")).on)
assert(setpoint(smes, "input_w").max == 200000.0, "tg's 200 kW rate")
assert(setpoint(smes, "output_w").value == 200000.0, "and both dials wide open")
assert(assert(toggle(smes, "l2", "input")).on, "it takes from the backbone")
assert(toggle(smes, "l1", "output") == nil, "and stands on no other line")

-- The four things it does, in the framework's two verbs.
ui_controls.set(p, "output_w", "min")
t.tick()
assert(setpoint(t.ui(p), "output_w").value == 0.0, "the throttle went to nothing")
ui_controls.set(p, "output_w", 1e+30)
t.tick()
assert(setpoint(t.ui(p), "output_w").value == 200000.0,
    "and a client cannot dial past the unit's rate")
ui_controls.toggle(p, "output_breaker")
t.tick()
assert(not assert(toggle(t.ui(p), "output_breaker")).on, "the breaker opened")
assert(word(readout(t.ui(p), "throttles.output").value) == "throttles.line.breaker_open", "and the lamp says so")
assert(t.ledger_has("MachineSetpoint"), "re-dialling a throttle is on the record")

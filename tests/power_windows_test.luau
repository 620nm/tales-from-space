-- The two panels the grid wears, from the other side of the glass.
--
-- An APC and a power storage unit are the same window with different
-- words: a store, whatever knobs the machine has of its own, and a
-- block per cable colour that actually runs under it. Neither is a
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
    spawns: [(2, 2)],
    cables: [
        (1, 1, 2, 0, 2), (1, 1, 2, 0, 4), (2, 1, 2, 4, 8), (3, 1, 2, 4, 8),
        (4, 1, 2, 0, 8), (1, 2, 2, 0, 1),
        (1, 2, 1, 0, 4), (2, 2, 1, 4, 8), (3, 2, 1, 4, 8), (4, 2, 1, 4, 8),
        (5, 2, 1, 0, 4), (5, 2, 1, 0, 8), (6, 2, 1, 0, 8),
    ],
    labels: [(1, 2, "Engineering")],
)]==], 7)

local p = t.join()
t.tick()
t.run_seconds(3) -- the electrical pass is 0.5 Hz; let one land

local function readout(ui, label)
    for _, r in ipairs(ui.readouts) do
        if r.label == label then
            return r
        end
    end
    return nil
end

local function toggle(ui, field, option)
    for _, tog in ipairs(ui.toggles) do
        if tog.field == field and tog.option == option then
            return tog
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

local function walk(dir)
    t.move(p, dir)
    t.run_ticks(5)
end

-- ---------------------------------------------------------------
-- THE AREA PANEL. Three modules: the cell it keeps, the channels only
-- it has, and a block for each of the two lines under it.
-- ---------------------------------------------------------------
t.click(p, 1, 2, t.target_at(1, 2))
t.tick()
local apc = t.ui(p)
assert(apc, "clicking the panel opens its window")
assert(apc.document == "modules" and apc.presentation == "modules",
    "the shared module document, not a device-specific kind")

assert(readout(apc, "stored").section == "battery", "the store is a module")
assert(readout(apc, "capacity").value == "1.00 MJ", "tg's 1 MJ cell")
assert(apc.gauge and apc.gauge > 0.0, "and the gauge reads it")
for _, channel in ipairs({ "equipment", "lighting", "environment" }) do
    assert(readout(apc, channel).section == "channels", channel .. " is a channel")
    assert(readout(apc, channel).value == "on", "a fed panel sheds nothing")
end
assert(readout(apc, "alarm").value == "clear", "and calls no alarm")
assert(#apc.setpoints == 0, "an APC has no dial: the ladder is the pass's")

-- The master breaker is the one switch over the three channels that the
-- ladder does not own -- so it IS a control, unlike the channels
-- themselves, and it takes the room with it.
assert(toggle(apc, "breaker").on, "the main breaker ships closed")
assert(toggle(apc, "breaker").section == "channels", "beside the lamps it gates")
t.ui_act(p, "toggle", '{"field":"breaker"}')
t.run_seconds(3)
assert(not t.apc_at(1, 2).operating, "the breaker opened")
assert(not toggle(t.ui(p), "breaker").on, "and the panel says so")
assert(not t.apc_at(1, 2).lighting, "a panel that is not operating feeds nothing")
assert(not t.lit(6, 2), "so its room is dark on a full cell")
assert(t.ledger_has("MachineToggled"), "throwing it is on the record")
t.ui_act(p, "toggle", '{"field":"breaker"}')
t.run_seconds(3)
assert(t.apc_at(1, 2).operating and t.lit(6, 2), "and closing it brings the room back")

assert(toggle(apc, "l1", "output").on, "L1 feeds the room")
assert(toggle(apc, "l1", "output").section == "port L1", "under its own heading")
assert(toggle(apc, "l2", "input").on, "L2 is where it takes from")
assert(toggle(apc, "l3", "output") == nil, "and there is no blue main under it")
assert(readout(apc, "out").value:find("W", 1, true), "a port says what it carried")

-- The one control the panel publishes answers, and lands on the record.
t.ui_act(p, "toggle", '{"field":"l1","option":"bidirectional"}')
t.tick()
assert(t.ports_at(1, 2).l1.mode == "bidirectional", "the port turned round")
assert(toggle(t.ui(p), "l1", "bidirectional").on, "and the panel says so")
assert(t.ledger_has("MachineToggled"), "turning a port is on the record")
t.ui_act(p, "toggle", '{"field":"l1","option":"output"}')
t.run_seconds(3)
assert(t.lit(6, 2), "the room circuit is feeding its lamp again")

-- ---------------------------------------------------------------
-- THE HOSTILE CLIENT. A channel is not a switch on this panel and a
-- port on a layer with no cable is not a control at all -- the window
-- in front of the player IS the whitelist, so neither is refused
-- politely, they are simply not there.
-- ---------------------------------------------------------------
t.ui_act(p, "toggle", '{"field":"equipment"}')
t.ui_act(p, "toggle", '{"field":"lighting"}')
t.tick()
assert(t.apc_at(1, 2).equipment, "a channel nobody offered stays where it was")
assert(t.apc_at(1, 2).lighting, "both of them")

t.ui_act(p, "toggle", '{"field":"l3","option":"input"}')
t.ui_act(p, "toggle", '{"field":"l1","option":"sideways"}')
t.tick()
assert(t.ports_at(1, 2).l3 == nil, "there is no third port to have moved")
assert(t.ports_at(1, 2).l1.mode == "output", "and no mode nobody named")

-- ---------------------------------------------------------------
-- THE BANK. The same store module, its own two breakers and two
-- throttles, and ONE port -- because one line runs under it.
-- ---------------------------------------------------------------
walk("east")
walk("east")
t.click(p, 4, 1, t.target_at(4, 1))
t.tick()
local smes = t.ui(p)
assert(smes, "clicking the bank opens its window")
assert(smes.document == "modules" and smes.presentation == "modules",
    "the same module document")
assert(readout(smes, "stored").section == "battery", "the same store module")
assert(readout(smes, "capacity").value == "5.00 MJ", "five standard cells")
assert(toggle(smes, "input_breaker").on, "both breakers closed out of the box")
assert(toggle(smes, "output_breaker").on)
assert(setpoint(smes, "input_w").max == 200000.0, "tg's 200 kW rate")
assert(setpoint(smes, "output_w").value == 200000.0, "and both dials wide open")
assert(toggle(smes, "l2", "input").on, "it takes from the backbone")
assert(toggle(smes, "l1", "output") == nil, "and stands on no other line")

-- The four things it does, in the framework's two verbs.
t.ui_act(p, "set", '{"field":"output_w","value":"min"}')
t.tick()
assert(setpoint(t.ui(p), "output_w").value == 0.0, "the throttle went to nothing")
t.ui_act(p, "set", '{"field":"output_w","value":1e30}')
t.tick()
assert(setpoint(t.ui(p), "output_w").value == 200000.0,
    "and a client cannot dial past the unit's rate")
t.ui_act(p, "toggle", '{"field":"output_breaker"}')
t.tick()
assert(not toggle(t.ui(p), "output_breaker").on, "the breaker opened")
assert(readout(t.ui(p), "output").value == "breaker open", "and the lamp says so")
assert(t.ledger_has("MachineSetpoint"), "re-dialling a throttle is on the record")

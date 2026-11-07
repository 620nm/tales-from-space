local ui_controls = require("@helpers/ui_controls")

-- The gas turbine console's window (tg turbine_computer.dm:50-119): the
-- console and the core rotor are endpoints on the room panel's hub, an
-- unlinked console offers the working turbine there, linking it reads
-- the rotor over the wire, and its power switch and intake valve drive
-- it the same way (lib/power/gas_turbine_console.luau over
-- lib/power/gas_turbine_service.luau).

local CHANNEL = "turbine"

-- A powered room: the generator feeds the APC, whose socket at (3, 2)
-- cords the console and the rotor (docs/POWER.md, "Outlets and cords").
-- The panel is also the hub both endpoints are joined to.
t.world(
    [==[(
    name: "turbine control room",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base")])),
        'o': (composition: (components: [(component: "station_base")]), fixture: Some(Outlet)),
    },
    levels: [
        (
            rows: [
                "########",
                "#G.....#",
                "#a.o...#",
                "#......#",
                "#......#",
                "########",
            ],
            networks: [
                (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
            ],
            structures: [
                (4, 4, "player_spawn"),
                (1, 2, "apc", { "network_1": "network_card" }),
                (2, 3, "inlet_compressor", "closed", { "dir": "east" }),
                (3, 3, "core_rotor", "closed", { "dir": "east" }),
                (4, 3, "turbine_outlet", "closed", { "dir": "east" }),
            ],
            machines: [(5, 4, "turbine_computer")],
            links: [(1, 2, 3, 3), (1, 2, 5, 4)],
        ),
    ],
)]==],
    0
)

local p = t.join()
t.tick()

local function script_data(): ui_controls.Record
    local panel = ui_controls.record(assert(t.ui(p, CHANNEL), "the console's window is open"))
    local script = panel.script
    return ui_controls.record(if script then ui_controls.record(script).data else panel.data)
end

local function control(suffix: string): string
    local address = assert(t.ui_document(p, CHANNEL), "the window has an address")
    return "doc/" .. address.document .. "/" .. address.generation .. suffix
end

local function scope(): ui_controls.Scope
    return assert(t.ui_document(p, CHANNEL), "the window has an address")
end

-- Requests cross the network and replies redraw; run until one lands.
local function eventually(holds: () -> boolean, seconds: number): boolean
    local waited = 0
    while not holds() do
        if waited >= seconds then
            return false
        end
        t.run_seconds(0.2)
        waited += 0.2
    end
    return true
end

local function open_console()
    assert(t.hands(p).held == nil, "an empty hand opens the console")
    t.click(p, 5, 4, assert(t.target_at(p, 5, 4, "turbine_computer")))
    t.run_ticks(2)
end

-- An unlinked console opens, says so, and offers the hub's one turbine.
open_console()
assert(script_data().linked == false, "an unlinked console discloses no rotor")
assert(ui_controls.find(p, "/unlinked", scope()), "and says so")
assert(not ui_controls.find(p, "/toggle_power", scope()), "with no switch to press")
assert(#ui_controls.rows(script_data().candidates) == 1, "the working turbine is offered")

-- Link it from the window.
t.ui_press(p, control("/candidate/0/select"))
assert(
    eventually(function()
        return script_data().connected == true
    end, 5),
    "the linked rotor answers over the network"
)

-- Linked to a whole line, the window shows the rotor's readout.
local reading = script_data()
assert(reading.kind == "turbine" and reading.linked == true, "the console reads its rotor")
assert(reading.connected == true, "over a whole line")
assert(reading.active == false, "which stands idle")
for _, field in ipairs({ "rpm", "power_w", "integrity", "max_rpm", "max_temperature_k", "intake_k", "intake" }) do
    ui_controls.number(reading[field])
end
assert(ui_controls.number(reading.max_rpm) > 0, "the readout carries the rotor's speed limit")
assert(ui_controls.find(p, "/toggle_power", scope()), "the power switch is drawn")

-- The switch starts the rotor.
t.ui_press(p, control("/toggle_power"))
assert(
    eventually(function()
        return script_data().active == true
    end, 5),
    "the switch starts the rotor"
)

-- The valve sets the rotor's intake: typed, then stepped up one percent.
local valve = control("/regulate")
t.ui_edit(p, valve, "0.5")
t.ui_press(p, valve, "change")
assert(
    eventually(function()
        return math.abs(ui_controls.number(script_data().intake) - 0.5) < 1e-6
    end, 5),
    "the valve sets the intake"
)
-- Text acts are paced (docs/TGUI.md); let the typed act's window pass.
t.run_seconds(0.6)
t.ui_press(p, control("/regulate/up"))
assert(
    eventually(function()
        return math.abs(ui_controls.number(script_data().intake) - 0.51) < 1e-6
    end, 5),
    "a step raises it one percent"
)

-- An idle shaft is under tg's 1000 rpm, so the switch stops it again.
t.ui_press(p, control("/toggle_power"))
assert(
    eventually(function()
        return script_data().active == false
    end, 5),
    "the switch stops the rotor"
)

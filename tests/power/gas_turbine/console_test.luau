local ui_controls = require("@helpers/ui_controls")

-- The gas turbine console's window (tg turbine_computer.dm:50-119): an
-- unlinked console says so; linked to a whole line it shows the rotor's
-- readout, its power switch starts and stops the rotor, and its intake
-- valve sets the compressor's regulator (lib/power/gas_turbine_console.luau
-- over lib/power/gas_turbine_run.luau).

local CHANNEL = "turbine"

-- A powered room: the generator feeds the APC, whose socket at (3, 2)
-- cords the console and the rotor (docs/POWER.md, "Outlets and cords").
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
                (1, 2, "apc"),
                (2, 3, "inlet_compressor", "closed", { "dir": "east" }),
                (3, 3, "core_rotor", "closed", { "dir": "east" }),
                (4, 3, "turbine_outlet", "closed", { "dir": "east" }),
            ],
            machines: [(5, 4, "turbine_computer")],
            items: [(5, 3, "multitool")],
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

local function open_console()
    assert(t.hands(p).held == nil, "an empty hand opens the console")
    t.click(p, 5, 4, t.target_at(p, 5, 4, "turbine_computer"))
    t.run_ticks(2)
end

-- An unlinked console opens and says it has no rotor.
open_console()
assert(script_data().linked == false, "an unlinked console discloses no rotor")
assert(ui_controls.find(p, "/unlinked", scope()), "and says so")
assert(not ui_controls.find(p, "/power/switch", scope()), "with no switch to press")
t.ui_close(p, CHANNEL)

-- Log the rotor in the multitool, then link the console to it.
t.click(p, 5, 3, t.target_at(p, 5, 3, "multitool"))
t.run_ticks(2)
assert(t.hands(p).held == "multitool", "the multitool is in hand")
t.click(p, 3, 3, t.target_at(p, 3, 3, "core_rotor"))
t.run_seconds(0.2)
t.click(p, 5, 4, t.target_at(p, 5, 4, "turbine_computer"))
t.run_seconds(0.5)
t.swap_hands(p)
t.run_ticks(1)

-- Linked to a whole line, the window shows the rotor's readout.
open_console()
local reading = script_data()
assert(reading.kind == "turbine" and reading.linked == true, "the console reads its rotor")
assert(reading.connected == true, "over a whole line")
assert(reading.active == false, "which stands idle")
for _, field in ipairs({ "rpm", "power_w", "integrity", "max_rpm", "max_temperature_k", "intake_k", "intake" }) do
    ui_controls.number(reading[field])
end
assert(ui_controls.number(reading.max_rpm) > 0, "the readout carries the rotor's speed limit")
assert(ui_controls.find(p, "/power/switch", scope()), "the power switch is drawn")

-- The switch starts the rotor.
t.ui_press(p, control("/power/switch"))
t.run_ticks(2)
assert(script_data().active == true, "the switch starts the rotor")

-- The valve sets the rotor's intake: typed, then stepped up one percent.
local valve = control("/intake/value")
t.ui_edit(p, valve, "50")
t.ui_press(p, valve, "change")
t.run_ticks(2)
assert(math.abs(ui_controls.number(script_data().intake) - 0.5) < 1e-6, "the valve sets the intake")
t.ui_press(p, control("/intake/up"))
t.run_ticks(2)
assert(math.abs(ui_controls.number(script_data().intake) - 0.51) < 1e-6, "a step raises it one percent")

-- An idle shaft is under tg's 1000 rpm, so the switch stops it again.
t.ui_press(p, control("/power/switch"))
t.run_ticks(2)
assert(script_data().active == false, "the switch stops the rotor")

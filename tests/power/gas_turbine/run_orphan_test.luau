local ui_controls = require("@helpers/ui_controls")

-- A running gas turbine outlives the body that threw its switch: each
-- section's turns are a task that body's chain started (the engine's
-- docs/luau-api/runtime.md), and a gibbed body is no transfer, so the rotor
-- keeps checking in and the heat behind its compressor keeps wearing it
-- (turbine.dm:634-640); a second player's window shows it. Turns cancelled
-- outright (a transfer off the map, a quarantine) leave a stalled run that
-- reads stopped; the switch shuts its rotor's stale watts off and restarts it.

local CHANNEL = "turbine"

-- The generator feeds the APC, whose socket at (6, 4) cords the console;
-- the main runs on under the rotor at (3, 1), the bus its watts feed.
-- The intake pocket at (1, 1) is far hotter than tier-one parts are rated
-- for (50000 K, turbine_parts.dm:43-47) and dense enough to stay so: the
-- tile's own floor and walls soak heat (a light 60000 K pocket read 30000 K
-- by the first pass), so it sits on reinforced floor inside reinforced
-- walls, the pack's least-radiant (`content/compositions.luau`), and the
-- sections stop air (turbine.dm:10). The tile ahead of the outlet, (5, 1),
-- starts as wall, sealing off an empty exhaust chamber at (6..7, 1). The
-- player stands in the air beside the rotor and the console.
t.world(
    [==[(
    name: "turbine hall",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'R': (composition: (components: [(component: "station_base"), (component: "reinforced_wall")])),
        'r': (composition: (components: [(component: "station_base"), (component: "reinforcement")])),
        'G': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base")])),
        'o': (composition: (components: [(component: "station_base")]), fixture: Some(Outlet)),
    },
    levels: [
        (
            rows: [
                "#R#######",
                "Rr...#..#",
                "#R...####",
                "#G......#",
                "#a....o.#",
                "#########",
            ],
            networks: [
                (x: 1, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 2, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 3, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 1, y: 4, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 1, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 2, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 3, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 4, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 5, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 6, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
            ],
            structures: [
                (3, 2, "player_spawn"),
                (1, 4, "apc"),
                (2, 1, "inlet_compressor", "closed", { "dir": "east" }),
                (3, 1, "core_rotor", "closed", { "dir": "east" }),
                (4, 1, "turbine_outlet", "closed", { "dir": "east" }),
            ],
            machines: [(4, 3, "turbine_computer")],
            items: [(2, 2, "multitool")],
            painted: [
                (1, 1, "hot_nitrogen"),
                (2, 2, "room_air"), (3, 2, "room_air"), (4, 2, "room_air"), (1, 3, "room_air"),
                (2, 3, "room_air"), (3, 3, "room_air"), (4, 3, "room_air"), (5, 3, "room_air"),
                (6, 3, "room_air"), (7, 3, "room_air"), (1, 4, "room_air"), (2, 4, "room_air"),
                (3, 4, "room_air"), (4, 4, "room_air"), (5, 4, "room_air"), (6, 4, "room_air"),
                (7, 4, "room_air"),
            ],
        ),
    ],
    blends: {
        "hot_nitrogen": (rows: [("n2", 1000.0)], temperature_k: 300000.0, amount: per_m3),
        "room_air": (rows: [("n2", 32.9), ("o2", 8.7)], temperature_k: 293.15, amount: per_m3),
    },
)]==],
    0
)

local p = t.join()
t.tick()

-- What `player`'s console window shows.
local function reading(player: number): ui_controls.Record
    local panel = ui_controls.record(assert(t.ui(player, CHANNEL), "the console's window is open"))
    local script = panel.script
    return ui_controls.record(if script then ui_controls.record(script).data else panel.data)
end

local function integrity(player: number): number
    return ui_controls.number(reading(player).integrity)
end

-- Runs until `holds` answers true, at most `seconds`: the window redraws
-- every 2 s, so a pass shows up to a refresh late.
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

local function click(player: number, x: number, y: number, id: string, seconds: number): ()
    t.click(player, x, y, t.target_at(player, x, y, id))
    t.run_seconds(seconds)
end

-- Link the console to the rotor, open its window and throw the switch.
click(p, 2, 2, "multitool", 0.2)
assert(t.hands(p).held == "multitool", "the multitool is in hand")
click(p, 3, 1, "core_rotor", 0.2)
click(p, 4, 3, "turbine_computer", 0.5)
t.swap_hands(p)
t.run_ticks(1)
click(p, 4, 3, "turbine_computer", 0.2)
local address = assert(t.ui_document(p, CHANNEL), "the window has an address")
t.ui_press(p, "doc/" .. address.document .. "/" .. address.generation .. "/toggle_power")
t.run_ticks(2)
assert(reading(p).active == true, "the switch starts a linked turbine")

-- One pass of wear, then the body goes.
local intake_k = ui_controls.number(reading(p).intake_k)
local rating_k = ui_controls.number(reading(p).max_temperature_k)
local under = string.format("the intake reads %.0f K, under %.0f K", intake_k, rating_k)
assert(intake_k > rating_k, under)
assert(eventually(function()
    return integrity(p) < 100
end, 5), "heat past the rating wears the rotor")
local before = integrity(p)
assert(t.staff_gib(p), "the body that threw the switch is gone")

-- A second player opens the console: the run still turns, still wearing.
local q = t.join()
t.run_ticks(2)
assert(t.hands(q).held == nil, "an empty hand opens the console")
click(q, 4, 3, "turbine_computer", 0.2)
assert(reading(q).active == true, "the run outlives its starter")
assert(eventually(function()
    return integrity(q) < before - 0.3
end, 8), "and its rotor still takes its turns")

-- The rotor's last `watts` setpoint: rows are written only on a change.
local function watts(): number?
    local last: number? = nil
    for _, row in ipairs(t.ledger_rows("MachineSetpoint")) do
        local pos = row.pos
        if row.field == "watts" and pos ~= nil and pos[1] == 3 and pos[2] == 1 then
            last = ui_controls.number(row.value)
        end
    end
    return last
end

-- Open the exhaust: the shaft spins and the rotor feeds the grid.
assert(t.set_composition(5, 1, "plating"), "the exhaust opens")
assert(eventually(function()
    return ui_controls.number(reading(q).rpm) > 0
end, 6), "hot gas through the stages spins the shaft")
local spun = assert(watts(), "the spinning rotor set its watts")
assert(spun > 0, "the spinning rotor feeds the grid")

-- Every task the pack holds cancelled outright, as a quarantine or a
-- transfer off the map does (the engine's docs/luau-api/runtime.md): no
-- turn runs to take the watts off, so the rotor keeps feeding them.
assert(t.cancel_mod_tasks("lunatic/tfs") >= 3, "the three sections' turns are cancelled")
t.run_seconds(6)
assert(watts() == spun, "a cancelled run keeps its last setpoint")
-- The window's own refresh went with the tasks; reopening it reads afresh.
click(q, 4, 3, "turbine_computer", 0.2)
assert(reading(q).active == false, "a rotor two passes silent reads stopped")

-- Presses the switch in `player`'s open window.
local function toggle(player: number): ()
    local address = assert(t.ui_document(player, CHANNEL), "the window has an address")
    t.ui_press(player, "doc/" .. address.document .. "/" .. address.generation .. "/toggle_power")
    t.run_ticks(2)
end

-- The switch restarts it: each section shut, the rotor's watts taken off,
-- then turning again in a new run.
toggle(q)
assert(watts() == 0, "the switch takes the stalled rotor's watts off")
assert(reading(q).active == true, "and restarts the run")
assert(assert(t.structure_at(3, 1)).state == "running", "the rotor turns again")
assert(eventually(function()
    click(q, 4, 3, "turbine_computer", 0)
    return ui_controls.number(reading(q).rpm) > 0
end, 8), "and its sections take their turns afresh")
assert((watts() or 0) > 0, "feeding the grid again")

-- Stalled again with the breaker tripped, the rotor unfed: the switch
-- refuses the restart but still halts the run, taking its watts off.
assert(t.cancel_mod_tasks("lunatic/tfs") >= 3, "the new run's turns are cancelled")
t.run_seconds(6)
t.outage()
t.run_ticks(2)
click(q, 4, 3, "turbine_computer", 0.2)
toggle(q)
assert(reading(q).active == false, "an unfed rotor is refused its restart")
assert(watts() == 0, "and the refused stall's watts come off")

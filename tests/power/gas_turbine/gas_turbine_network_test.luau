local ui_controls = require("@helpers/ui_controls")

-- Which turbines a console may link to: the working ones standing on its
-- own hub. Two whole lines share the console's access point, a third
-- whole line stands on a second access point under the same router --
-- one network tree, but not the console's hub -- and a fourth line on
-- the console's hub has its outlet's panel open. The window offers the
-- two, drives whichever is picked, and can change its link between them.

local CHANNEL = "turbine"

t.world(
    [==[(
    name: "turbine networks",
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
                "##################",
                "#Ga.o...o...o....#",
                "#................#",
                "#................#",
                "#................#",
                "#................#",
                "##################",
            ],
            networks: [
                (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 5, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 6, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 7, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 8, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 9, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 10, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 11, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 12, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 13, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
            ],
            structures: [
                (10, 4, "player_spawn"),
                (2, 1, "apc"),
                (5, 1, "access_point", { "network_1": "network_card", "mount": "north" }),
                (13, 1, "access_point", { "network_1": "network_card", "mount": "north" }),
                (2, 3, "inlet_compressor", "closed", { "dir": "east" }),
                (3, 3, "core_rotor", "closed", { "dir": "east" }),
                (4, 3, "turbine_outlet", "closed", { "dir": "east" }),
                (6, 3, "inlet_compressor", "closed", { "dir": "east" }),
                (7, 3, "core_rotor", "closed", { "dir": "east" }),
                (8, 3, "turbine_outlet", "closed", { "dir": "east" }),
                (12, 3, "inlet_compressor", "closed", { "dir": "east" }),
                (13, 3, "core_rotor", "closed", { "dir": "east" }),
                (14, 3, "turbine_outlet", "closed", { "dir": "east" }),
                (2, 5, "inlet_compressor", "closed", { "dir": "east" }),
                (3, 5, "core_rotor", "closed", { "dir": "east" }),
                (4, 5, "turbine_outlet", "open", { "dir": "east" }),
            ],
            machines: [
                (9, 1, "network_router", { "network_1": "network_card" }),
                (10, 3, "turbine_computer"),
            ],
            links: [
                (9, 1, 5, 1), (9, 1, 13, 1),
                (5, 1, 3, 3), (5, 1, 7, 3), (5, 1, 3, 5), (5, 1, 10, 3),
                (13, 1, 13, 3),
            ],
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

local function press(suffix: string): ()
    local address = assert(t.ui_document(p, CHANNEL), "the window has an address")
    t.ui_press(p, "doc/" .. address.document .. "/" .. address.generation .. suffix)
end

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

local function rotor_state(x: number, y: number): string?
    return assert(t.structure_at(x, y)).state
end

-- Which of the hub's two rotors is turning, by its tile; 0 for neither.
local function running_rotor(): number
    local running = 0
    for _, x in ipairs({ 3, 7 }) do
        if rotor_state(x, 3) == "running" then
            assert(running == 0, "at most one linked turbine runs in this spec")
            running = x
        end
    end
    return running
end

t.click(p, 10, 3, assert(t.target_at(p, 10, 3, "turbine_computer")))
t.run_ticks(2)
assert(script_data().linked == false, "the console starts unlinked")
assert(
    #ui_controls.rows(script_data().candidates) == 2,
    "only the two working turbines on the console's own access point are offered"
)

-- Link the first and start it: its line turns, no other does.
press("/candidate/0/select")
assert(
    eventually(function()
        return script_data().connected == true
    end, 5),
    "the first turbine answers"
)
press("/toggle_power")
assert(
    eventually(function()
        return running_rotor() ~= 0
    end, 5),
    "starting from the console turns the linked turbine"
)
local first = running_rotor()
local first_selected = script_data().selected
assert(rotor_state(13, 3) == "closed", "the other access point's turbine stays still")
assert(rotor_state(3, 5) == "closed", "the broken line stays still")

-- Stop it, change the link to the second turbine, and start that one.
press("/toggle_power")
assert(
    eventually(function()
        return running_rotor() == 0
    end, 5),
    "the switch stops it again"
)
press("/candidate/1/select")
assert(
    eventually(function()
        return script_data().selected ~= first_selected and script_data().connected == true
    end, 5),
    "the second turbine answers"
)
-- A breath inside the link's per-address emission bucket (the engine's
-- docs/DEVICES.md ceilings) after the flurry of selections above.
t.run_seconds(2)
press("/toggle_power")
local other = if first == 3 then 7 else 3
assert(
    eventually(function()
        return running_rotor() == other
    end, 5),
    "changing the link drives the other turbine on the access point"
)
assert(rotor_state(13, 3) == "closed", "and never the one across the router")
press("/toggle_power")
assert(
    eventually(function()
        return running_rotor() == 0
    end, 5),
    "the second stops from the console too"
)

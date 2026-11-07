local laptop = require("@helpers/laptop")
local ui_controls = require("@helpers/ui_controls")
local ui_files = require("@helpers/ui_files")

-- The turbine is scriptable, and only from its own hub. A player installs
-- a guest on a second access point under the same router: it can see the
-- turbine in its whole-tree directory and asks it to start, and is
-- refused. The same player installs the toggling guest on the rotor's
-- own access point, and each button press there reads the turbine's
-- status over its `turbine.control` service and sends the other half of
-- the switch -- start a stopped turbine, stop a running one. No console
-- and no hand at the rotor take part after the installs.
local PROBE = [==[
local result = { commands = {} }
if event.kind == "button" then
    local target = nil
    for _, row in ipairs(directory or {}) do
        if row.service == "turbine.control" then target = row end
    end
    if target == nil then
        result.status = "fault"
    else
        table.insert(result.commands, {
            op = "service", id = "start", to = target.mac,
            service = "turbine.control", request = true,
            payload = { op = "start" },
        })
        result.timer = { id = "start", seconds = 6 }
    end
    result.accepted = true
elseif event.kind == "service" then
    local payload = type(event.payload) == "table" and event.payload or {}
    result.status = payload.ok and "idle" or "fault"
    result.timer = false
elseif event.kind == "timeout" then
    result.status = "fault"
end
return result
]==]

local PROGRAM = [==[
local result = { commands = {} }
local function drive(op)
    local target = nil
    for _, row in ipairs(directory or {}) do
        if row.service == "turbine.control" then target = row end
    end
    if target == nil then
        result.status = "fault"
        return
    end
    table.insert(result.commands, {
        op = "service", id = op, to = target.mac,
        service = "turbine.control", request = true,
        payload = { op = op },
    })
    result.timer = { id = op, seconds = 6 }
end
if event.kind == "button" then
    drive("status")
    result.accepted = true
elseif event.kind == "service" then
    local payload = type(event.payload) == "table" and event.payload or {}
    if payload.kind ~= "turbine.status" or payload.ok ~= true then
        result.status = "fault"
        result.timer = false
    elseif payload.op == "status" then
        drive(payload.status.active and "stop" or "start")
    else
        result.status = "idle"
        result.timer = false
    end
elseif event.kind == "timeout" then
    result.status = "fault"
end
return result
]==]

t.world(
    [==[(
    name: "turbine guest",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
    },
    levels: [
        (
            rows: [
                "#############",
                "#Gao....o...#",
                "#...........#",
                "#...........#",
                "#############",
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
            ],
            structures: [
                (5, 2, "player_spawn", { "jobs": "assistant" }),
                (2, 1, "apc"),
                (5, 1, "access_point", { "network_1": "network_card", "mount": "north" }),
                (7, 1, "airlock_button", { "mount": "north" }),
                (10, 1, "access_point", { "network_1": "network_card", "mount": "north" }),
                (11, 1, "airlock_button", { "mount": "north" }),
                (2, 3, "inlet_compressor", "closed", { "dir": "east" }),
                (3, 3, "core_rotor", "closed", { "dir": "east" }),
                (4, 3, "turbine_outlet", "closed", { "dir": "east" }),
            ],
            machines: [(9, 1, "network_router", { "network_1": "network_card" })],
            links: [(9, 1, 5, 1), (9, 1, 10, 1), (5, 1, 7, 1), (5, 1, 3, 3), (10, 1, 11, 1)],
            items: [(5, 2, "laptop")],
        ),
    ],
)]==],
    0
)

local p = t.join()
t.run_seconds(0.5)

local function all_in(state: string): boolean
    for x = 2, 4 do
        if assert(t.structure_at(x, 3)).state ~= state then
            return false
        end
    end
    return true
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

type Step = "east" | "west"
local function walk(step: Step, tiles: number): ()
    for _ = 1, tiles do
        t.move(p, step)
        t.run_ticks(4)
    end
end

-- Install `source` as the controller guest of the access point at (ap_x, 1);
-- the player stands south of it holding the laptop.
local function install(ap_x: number, source: string, name: string): ()
    assert(laptop.connect(p, ap_x, 1, "access_point") ~= nil, "the laptop reaches the AP")
    laptop.unlock(p)
    t.run_ticks(2)
    ui_files.create(p, "host", "disl", name)
    t.run_ticks(2)
    local uid = string.format("%d", ui_controls.number(ui_controls.record(laptop.ui(p).open).uid))
    t.run_seconds(0.5) -- the pacing window on text acts (docs/TGUI.md)
    ui_files.save(p, source)
    t.run_ticks(2)
    assert(ui_controls.record(laptop.ui(p).open).body == source, "the source is saved on the AP")
    ui_files.program(p, "controller", uid)
    t.run_ticks(2)
    assert(
        ui_controls.record(ui_controls.rows(laptop.ui(p).program_slots)[1].state).id
            == "program_slots.state.loaded",
        "the controller slot accepts the guest"
    )
    laptop.close(p)
end

-- First the probe on the far access point: same router, another hub.
laptop.ready(p, 5, 2)
walk("east", 5)
install(10, PROBE, "turbine_probe")
t.drop(p)
t.run_ticks(2)
walk("east", 1)
t.click(p, 11, 1, assert(t.target_at(p, 11, 1, "airlock_button")))
t.run_seconds(5)
assert(all_in("closed"), "a guest on another access point cannot start the turbine")

-- Then the toggler on the rotor's own access point.
laptop.take(p, 10, 2)
walk("west", 6)
local at_x, at_y = t.pos(p)
assert(at_x == 5 and at_y == 2, "back at the turbine's access point")
install(5, PROGRAM, "turbine_ctl")
t.drop(p)
t.run_ticks(2)

-- Stand at the button and press it: the guest starts the turbine.
walk("east", 2)
local bx, by = t.pos(p)
assert(bx == 7 and by == 2, "the player stands at the button")
t.click(p, 7, 1, assert(t.target_at(p, 7, 1, "airlock_button")))
assert(
    eventually(function()
        return all_in("running")
    end, 15),
    "the guest reads the turbine stopped and starts it"
)

-- Press again: the guest reads it running and stops it.
t.click(p, 7, 1, assert(t.target_at(p, 7, 1, "airlock_button")))
assert(
    eventually(function()
        return all_in("closed")
    end, 15),
    "the guest reads the turbine running and stops it"
)
assert(#t.ledger_rows("script_error") == 0, "no script faults along the way")

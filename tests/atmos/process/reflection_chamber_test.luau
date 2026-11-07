local network_matter = require("@helpers/network_matter")

local function has_item(x: number, y: number, id: string): boolean
    for _, name in ipairs(t.items_at(x, y)) do
        if name == id then
            return true
        end
    end
    return false
end

local function pick_up(p: number, x: number, y: number, id: string)
    local target = assert(t.target_at(p, x, y, id), "expected item " .. id)
    t.click(p, x, y, target)
    t.run_ticks(2)
    assert(t.hands(p).held == id, "expected to hold " .. id)
end

local function click_structure(p: number, x: number, y: number, id: string)
    local target = assert(t.target_at(p, x, y, id), "expected structure " .. id)
    t.click(p, x, y, target)
    t.run_ticks(2)
end

-- ---------------------------------------------------------------------------
-- 1. East/West Layer-3 coupling, North/South + Layer-1/2 isolation, no rotation
-- ---------------------------------------------------------------------------
local COUPLING_WORLD = [==[(
    name: "reflection chamber coupling",
    blends: {
        "uf6_charge": (
            rows: [("uf6:gas", 40.0)],
            temperature_k: 380.0,
            amount: total,
        ),
    },
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base")])),
    },
    levels: [
        (
            rows: [
                "#####",
                "#...#",
                "#...#",
                "#...#",
                "#####",
            ],
            networks: [
                (x: 1, y: 2, network: "pipe", channel: "l3", kind: "standard", facing: 15),
                (x: 3, y: 2, network: "pipe", channel: "l3", kind: "standard", facing: 15),
                (x: 3, y: 2, network: "pipe", channel: "l2", kind: "standard", facing: 15),
                (x: 3, y: 2, network: "pipe", channel: "l1", kind: "standard", facing: 15),
                (x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
                (x: 2, y: 3, network: "pipe", channel: "l3", kind: "standard", facing: 15),
            ],
            structures: [
                (1, 1, "player_spawn"),
                (2, 2, "reflection_chamber", { "blend": "uf6_charge" }),
            ],
        ),
    ],
)]==]

t.world(COUPLING_WORLD, 0)
local p1 = t.join()
t.tick()

assert(bit32.band(assert(t.network_joined(1, 2, "pipe", "l3")), 4) ~= 0, "west l3 joins east to chamber")
assert(bit32.band(assert(t.network_joined(3, 2, "pipe", "l3")), 8) ~= 0, "east l3 joins west to chamber")
assert(t.network_joined(2, 1, "pipe", "l3") == 0, "north l3 stays unjoined")
assert(t.network_joined(2, 3, "pipe", "l3") == 0, "south l3 stays unjoined")
assert(t.network_joined(3, 2, "pipe", "l2") == 0, "east l2 stays unjoined")
assert(t.network_joined(3, 2, "pipe", "l1") == 0, "east l1 stays unjoined")

local chamber_entity = assert(t.structure_at(2, 2)).entity
assert(t.device_port_pressure(chamber_entity, 0) ~= nil, "west port 0 exists")
assert(t.device_port_pressure(chamber_entity, 1) ~= nil, "east port 1 exists")
assert(t.device_port_pressure(chamber_entity, 2) == nil, "only two axis ports exist")

local chamber_target = assert(t.target_at(p1, 2, 2, "reflection_chamber"))
for _, hint in ipairs(t.action_hints(p1, chamber_target)) do
    assert(
        hint.gesture ~= "alt_primary" and hint.gesture ~= "alt_secondary",
        "reflection_chamber exposes no rotation gesture"
    )
end
local ok_alt1 = pcall(t.use_item, p1, chamber_target, "alt_primary")
local ok_alt2 = pcall(t.use_item, p1, chamber_target, "alt_secondary")
assert(not ok_alt1 and not ok_alt2, "unoffered rotation gestures are rejected")
t.tick()
assert(bit32.band(assert(t.network_joined(1, 2, "pipe", "l3")), 4) ~= 0, "west l3 still joined after alt-click")
assert(t.network_joined(2, 1, "pipe", "l3") == 0, "north l3 still unjoined after alt-click")

t.run_seconds(3.0)
local tank_p = assert(t.tank_pressure(2, 2))
assert(math.abs(assert(network_matter.pressure(1, 2, "l3")) - tank_p) < 5.0, "west l3 equalizes pressure")
assert(math.abs(assert(network_matter.pressure(3, 2, "l3")) - tank_p) < 5.0, "east l3 equalizes pressure")
assert((assert(network_matter.gas(1, 2, "l3"))["uf6"] or 0) > 2.0, "west l3 receives uf6")
assert((assert(network_matter.gas(3, 2, "l3"))["uf6"] or 0) > 2.0, "east l3 receives uf6")
assert((assert(network_matter.gas(2, 1, "l3"))["uf6"] or 0) == 0, "north l3 receives no uf6")
assert((assert(network_matter.gas(2, 3, "l3"))["uf6"] or 0) == 0, "south l3 receives no uf6")
assert((assert(network_matter.gas(3, 2, "l2"))["uf6"] or 0) == 0, "east l2 receives no uf6")
assert((assert(network_matter.gas(3, 2, "l1"))["uf6"] or 0) == 0, "east l1 receives no uf6")

-- ---------------------------------------------------------------------------
-- 2. Nonlinear UF6 heating vs inert N2 & thermal state ladder
-- ---------------------------------------------------------------------------
local THERMAL_WORLD = [==[(
    name: "reflection chamber thermal ladder",
    blends: {
        "n2_inert": (
            rows: [("n2", 50.0)],
            temperature_k: 380.0,
            amount: total,
        ),
        "uf6_low": (
            rows: [("uf6:gas", 20.0)],
            temperature_k: 380.0,
            amount: total,
        ),
        "uf6_double": (
            rows: [("uf6:gas", 40.0)],
            temperature_k: 380.0,
            amount: total,
        ),
        "uf6_ladder": (
            rows: [("uf6:gas", 200.0)],
            temperature_k: 450.0,
            amount: total,
        ),
    },
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base")])),
    },
    levels: [
        (
            rows: [
                "#########",
                "#.......#",
                "#.......#",
                "#########",
            ],
            structures: [
                (1, 2, "player_spawn"),
                (1, 1, "reflection_chamber", { "blend": "n2_inert" }),
                (3, 1, "reflection_chamber", { "blend": "uf6_low" }),
                (5, 1, "reflection_chamber", { "blend": "uf6_double" }),
                (7, 1, "reflection_chamber", { "blend": "uf6_ladder" }),
            ],
        ),
    ],
)]==]

t.world(THERMAL_WORLD, 0)
local p2 = t.join()
t.run_ticks(2)

assert(assert(t.structure_at(1, 1)).state == "standby", "inert N2 chamber stays on standby")
assert(assert(t.structure_at(1, 1)).sprite == "reflection_chamber", "standby sprite")
assert(assert(t.structure_at(7, 1)).state == "subcritical", "350 K UF6 chamber enters subcritical")
assert(assert(t.structure_at(7, 1)).sprite == "reflection_chamber_subcritical", "subcritical sprite")

local ex_standby = assert(t.examine(p2, 1, 1, assert(t.target_at(p2, 1, 1, "reflection_chamber"))))
assert(table.concat(ex_standby.lines, " "):find("standby", 1, true) ~= nil, "examine reports standby")

t.run_seconds(5.0)
local inert_vessel = assert(t.vessel_at(1, 1, "reflection_chamber"))
assert(math.abs(inert_vessel.temp_k - 380.0) < 0.5, "inert N2 does not self-heat")
assert(assert(t.structure_at(1, 1)).state == "standby", "inert N2 stays on standby")

local dt_low = assert(t.vessel_at(3, 1, "reflection_chamber")).temp_k - 380.0
local dt_double = assert(t.vessel_at(5, 1, "reflection_chamber")).temp_k - 380.0
assert(dt_low > 15.0, "20 mol UF6 heats appreciably")
assert(dt_double > 1.5 * dt_low, "doubling UF6 moles delivers > 2x heating power (> 1.5x dT)")

assert(assert(t.structure_at(7, 1)).state == "critical", "200 mol UF6 reaches critical (>= 600 K)")
assert(assert(t.structure_at(7, 1)).sprite == "reflection_chamber_critical", "critical sprite")

t.run_seconds(13.0)
assert(assert(t.structure_at(7, 1)).state == "overheated", "200 mol UF6 reaches overheated (>= 1100 K)")
assert(assert(t.structure_at(7, 1)).sprite == "reflection_chamber_overheated", "overheated sprite")

t.run_seconds(18.0)
assert(assert(t.structure_at(7, 1)).state == "supercritical", "200 mol UF6 reaches supercritical (>= 1800 K)")
assert(assert(t.structure_at(7, 1)).sprite == "reflection_chamber_supercritical", "supercritical sprite")

-- ---------------------------------------------------------------------------
-- 3. Frame assembly, panel gating & crowbar teardown
-- ---------------------------------------------------------------------------
local BUILD_WORLD = [==[(
    name: "reflection chamber construction",
    blends: {
        "uf6_active": (
            rows: [("uf6:gas", 20.0)],
            temperature_k: 380.0,
            amount: total,
        ),
    },
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base")])),
    },
    levels: [
        (
            rows: [
                "#####",
                "#...#",
                "#...#",
                "#...#",
                "#####",
            ],
            structures: [
                (2, 2, "player_spawn"),
                (3, 1, "reflection_chamber", { "blend": "uf6_active" }),
                (1, 1, "machine_frame"),
            ],
            items: [
                (1, 2, "cable_coil"),
                (3, 2, "machine_board.reflection_chamber"),
                (1, 3, "metal"),
                (2, 3, "screwdriver"),
                (3, 3, "crowbar"),
            ],
        ),
    ],
)]==]

t.world(BUILD_WORLD, 0)
local p3 = t.join()
t.run_ticks(2)

pick_up(p3, 1, 2, "cable_coil")
click_structure(p3, 1, 1, "machine_frame")
t.run_seconds(2.5)
assert(assert(t.structure_at(1, 1)).state == "wired", "frame wired")
t.drop(p3)
t.run_ticks(2)

pick_up(p3, 3, 2, "machine_board.reflection_chamber")
click_structure(p3, 1, 1, "machine_frame")
assert(assert(t.structure_at(1, 1)).state == "boarded", "board installed")

pick_up(p3, 2, 2, "cable_coil")
click_structure(p3, 1, 1, "machine_frame")
t.drop(p3)
t.run_ticks(2)

pick_up(p3, 1, 3, "metal")
for _ = 1, 5 do
    click_structure(p3, 1, 1, "machine_frame")
end
t.drop(p3)
t.run_ticks(2)

pick_up(p3, 2, 3, "screwdriver")
click_structure(p3, 1, 1, "machine_frame")
t.run_seconds(4.5)
local built = assert(t.structure_at(1, 1))
assert(built.id == "reflection_chamber", "frame completes into reflection_chamber")
assert(built.state == "standby", "newly built chamber starts on standby")

click_structure(p3, 1, 1, "reflection_chamber")
assert(assert(t.structure_at(1, 1)).state == "open", "screwdriver opens standby panel")
assert(assert(t.structure_at(1, 1)).sprite == "reflection_chamber_open", "open sprite")

click_structure(p3, 1, 1, "reflection_chamber")
assert(assert(t.structure_at(1, 1)).state == "standby", "screwdriver closes panel back to standby")

assert(assert(t.structure_at(3, 1)).state == "subcritical", "charged chamber is active")
click_structure(p3, 3, 1, "reflection_chamber")
assert(assert(t.structure_at(3, 1)).state == "subcritical", "screwdriver refuses to open active chamber")

click_structure(p3, 1, 1, "reflection_chamber")
assert(assert(t.structure_at(1, 1)).state == "open", "panel reopened for deconstruction")
t.drop(p3)
t.run_ticks(2)

pick_up(p3, 3, 3, "crowbar")
click_structure(p3, 1, 1, "reflection_chamber")
t.run_seconds(4.5)
assert(assert(t.structure_at(1, 1)).id == "machine_frame", "crowbar restores machine_frame")
assert(has_item(1, 1, "machine_board.reflection_chamber"), "crowbar yields reflection_chamber board")
assert(has_item(1, 1, "cable_coil"), "crowbar yields cable_coil")
assert(has_item(1, 1, "metal"), "crowbar yields metal")

-- ---------------------------------------------------------------------------
-- 4. Overpressure rupture (> 5000 kPa -> broken, dumps UF6 into room)
-- ---------------------------------------------------------------------------
local RUPTURE_WORLD = [==[(
    name: "reflection chamber rupture",
    blends: {
        "uf6_overpressure": (
            rows: [("uf6:gas", 800.0)],
            temperature_k: 2000.0,
            amount: total,
        ),
        "co2_tracer": (
            rows: [("co2", 120.0)],
            temperature_k: 300.0,
            amount: total,
        ),
    },
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base")])),
    },
    levels: [
        (
            rows: [
                "#######",
                "#.....#",
                "#.....#",
                "#######",
            ],
            networks: [
                (x: 3, y: 2, network: "pipe", channel: "l3", kind: "standard", facing: 15),
                (x: 5, y: 2, network: "pipe", channel: "l3", kind: "standard", facing: 15),
            ],
            structures: [
                (2, 1, "player_spawn"),
                (1, 2, "stationary_tank", { "blend": "co2_tracer" }),
                (2, 2, "manual_valve"),
                (4, 2, "reflection_chamber", { "blend": "uf6_overpressure" }),
            ],
        ),
    ],
)]==]

t.world(RUPTURE_WORLD, 0)
local p_rupture = t.join()
t.tick()

assert(bit32.band(assert(t.network_joined(3, 2, "pipe", "l3")), 4) ~= 0, "west pipe joins chamber before rupture")
assert(bit32.band(assert(t.network_joined(5, 2, "pipe", "l3")), 8) ~= 0, "east pipe joins chamber before rupture")
assert((assert(t.room_gas(3, 2))["uf6"] or 0) == 0, "room initially holds no uf6")
t.run_seconds(10.0)
assert(assert(t.structure_at(4, 2)).state == "broken", "overpressured chamber ruptures into broken state")
assert((assert(t.room_gas(3, 2))["uf6"] or 0) > 10.0, "ruptured chamber dumps uf6 into room")
assert(bit32.band(assert(t.network_joined(3, 2, "pipe", "l3")), 4) == 0, "west pipe detaches from ruptured chamber")
assert(t.network_joined(5, 2, "pipe", "l3") == 0, "east pipe detaches from ruptured chamber")

click_structure(p_rupture, 2, 2, "manual_valve")
t.run_seconds(3.0)
assert((assert(network_matter.gas(3, 2, "l3"))["co2"] or 0) > 5.0, "opened valve feeds co2 into west pipe")
assert((assert(network_matter.gas(5, 2, "l3"))["co2"] or 0) == 0, "ruptured chamber no longer bridges west pipe to east pipe")
assert(assert(t.tank_pressure(4, 2)) == 0, "ruptured chamber shell does not refill from attached pipes")

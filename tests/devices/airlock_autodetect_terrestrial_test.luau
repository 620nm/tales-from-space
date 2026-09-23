-- Cold air outside, warm air in: both ends breathe, so no pumping.
-- The lock only guards passage: one leaf shuts, the other opens.
-- The cold end is a walled room and the chamber, open to it, holds
-- the same cold air: matter moves from the first tick, so a vacuum
-- chamber or a space edge would drain it and make the lock pump.
local AIRLOCK = [==[
(
    name: "Cold Outdoors Airlock",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        ' ': (composition: (substrate: Some("space"))), '.': (composition: (components: [(component: "station_base")])), '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
        'A': (composition: (components: [(component: "station_base")])),
        'o': (composition: (components: [(component: "station_base")]), fixture: Some(Outlet)),
    },
    rows: [
        "#############", "######.#.####", "#############",
        "#...........#", "#GA.o#..#...#", "#############",
        "             ",
    ],
    blends: {
        "vacuum": (temperature_k: 293.15, amount: per_tile),
        "supply": (rows: [("o2", 392.86967015394526), ("n2", 1477.93828296008)],
            temperature_k: 293.15, amount: per_tile),
        "cold_air": (rows: [("o2", 9.9), ("n2", 37.1)],
            temperature_k: 259.15, amount: per_tile),
    },
    painted: [(6, 1, "supply"), (6, 3, "cold_air"), (7, 3, "cold_air"),
        (6, 4, "cold_air"), (7, 4, "cold_air"), (8, 3, "cold_air"),
        (9, 3, "cold_air"), (10, 3, "cold_air"), (11, 3, "cold_air"),
        (9, 4, "cold_air"), (10, 4, "cold_air"), (11, 4, "cold_air"),
        (8, 1, "vacuum")],
    structures: [
        (3, 3, "player_spawn", { "jobs": "assistant" }),
        (9, 3, "player_spawn", { "jobs": "engineer" }),
        (4, 3, "access_point", { "network_1": "network_card", "file.airlock_controller": true, "program.controller": "airlock_controller", "mount": "north" }),
        (2, 3, "airlock_button", { "mount": "north" }), (7, 4, "airlock_button", { "mount": "south" }),
        (5, 3, "airlock", { "bolted": true }),
        (8, 3, "airlock", { "open": true, "bolted": false }),
        (6, 3, "bidirectional_vent", { "dir": "north" }),
        (6, 1, "passive_vent", { "channel": "l4", "pipe": "south" }),
        (8, 1, "passive_vent", { "channel": "l2", "pipe": "south" }),
        (2, 4, "apc"),
    ],
    links: [
        (4, 3, 2, 3), (4, 3, 5, 3), (4, 3, 6, 3),
        (4, 3, 8, 3), (4, 3, 7, 4),
    ],
    networks: [
        (x: 6, y: 2, network: "pipe", channel: "l4", kind: "standard", facing: 15),
        (x: 6, y: 2, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 7, y: 2, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 8, y: 2, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 1, y: 4, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 4, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 8, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
    ],
    items: [(3, 3, "laptop")],
)
]==]
local airlock_cycle = require("@helpers/airlock_cycle")
t.set_breathing(false)
t.world(AIRLOCK, 0)
local operator0 = t.join("assistant")
t.join("engineer")
t.run_ticks(20)

-- The premise, read after the world has run: both ends, and the
-- chamber open to the east leaf, still hold breathable air.
for _, x in ipairs({ 3, 6, 8, 9, 11 }) do
    local kpa = assert(t.room_pressure(x, 3))
    assert(kpa >= 85, "(" .. x .. ",3) holds breathable pressure: " .. kpa)
end

-- Both ends breathe: the west leaf opens with no pumping at all.
local operator = operator0
local since = airlock_cycle.mark()
local watched = airlock_cycle.watches()
t.click(operator, 2, 3, assert(t.target_at(operator, 2, 3, "airlock_button")))
t.run_ticks(2)
airlock_cycle.until_door(5, true, operator, since, function()
    local p = assert(t.door_at(8, 3))
    if assert(t.door_at(5, 3)).open or assert(t.door_at(5, 3)).moving then
        assert(not p.open and not p.moving and p.bolted, "the east leaf stays bolted while west moves")
    end
end)
assert(airlock_cycle.watches() == watched, "interlock sends no pressure watch")
assert(
    assert(t.door_at(8, 3)).bolted and not assert(t.door_at(8, 3)).open,
    "the east leaf ends bolted shut"
)

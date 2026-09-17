-- Vacuum outside, station east: the lock learns home by air alone.
-- Mirrored from the shipped map (station west there): space presses
-- west, the chamber fills, and the east leaf opens. A program that
-- trusted place would open the wrong leaf here.
local AIRLOCK = [==[
(
    name: "Mirrored Airlock",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        ' ': (composition: (substrate: Some("space"))), '.': (composition: (components: [(component: "station_base")])), '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
        'A': (composition: (components: [(component: "station_base")]), fixture: Some(Apc)),
        'o': (composition: (components: [(component: "station_base")]), fixture: Some(Outlet)),
    },
    rows: [
        "#############", "######.#.####", "#############",
        "#........... ", "#GA.o#..#... ", "############ ",
        "             ",
    ],
    blends: {
        "vacuum": (temperature_k: 293.15, amount: per_tile),
        "supply": (rows: [("o2", 392.86967015394526), ("n2", 1477.93828296008)],
            temperature_k: 293.15, amount: per_tile),
    },
    painted: [(6, 1, "supply"), (6, 3, "vacuum"), (7, 3, "vacuum"),
        (6, 4, "vacuum"), (7, 4, "vacuum"), (8, 3, "vacuum"),
        (1, 3, "vacuum"), (2, 3, "vacuum"), (3, 3, "vacuum"), (4, 3, "vacuum"),
        (8, 1, "vacuum")],
    structures: [
        (3, 3, "player_spawn", { "jobs": "engineer" }),
        (9, 3, "player_spawn", { "jobs": "assistant" }),
        (4, 3, "access_point", { "network_1": "network_card", "file.airlock_controller": true, "program.controller": "airlock_controller", "mount": "north" }),
        (2, 3, "airlock_button", { "mount": "north" }), (7, 4, "airlock_button", { "mount": "south" }),
        (5, 3, "airlock", { "open": true, "bolted": false }),
        (8, 3, "airlock", { "bolted": true }),
        (6, 3, "airlock_pump", { "dir": "north" }),
        (6, 1, "passive_vent", { "channel": "l4", "pipe": "south" }),
        (8, 1, "passive_vent", { "channel": "l2", "pipe": "south" }),
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
t.join("assistant")
local visitor = t.join("engineer")
t.run_ticks(20)

local CHAMBER = { { 6, 3 }, { 7, 3 }, { 6, 4 }, { 7, 4 } }
local function chamber()
    local parts = {}
    for _, tile in ipairs(CHAMBER) do
        table.insert(parts, tostring(t.room_pressure(tile[1], tile[2])))
    end
    return table.concat(parts, ",")
end
local function sealed_while(opening, partner, step, watched, admits)
    local checked = false
    return function()
        local d = assert(t.door_at(opening, 3))
        if d.open or d.moving then
            local p = assert(t.door_at(partner, 3))
            assert(
                not p.open and not p.moving and p.bolted,
                "door " .. partner .. " is bolted shut before " .. opening .. " moves"
            )
            if not checked then
                checked = true
                for _, tile in ipairs(CHAMBER) do
                    assert(
                        admits(assert(t.room_pressure(tile[1], tile[2]))),
                        tostring(step) .. ": chamber ready as door " .. opening .. " moves: " .. chamber()
                    )
                end
                assert(
                    airlock_cycle.watches() > watched,
                    tostring(step) .. ": a pressure watch completed after the press"
                )
            end
        end
    end
end

-- Space west presses: the east leaf is home and must open.
local since = airlock_cycle.mark()
local watched = airlock_cycle.watches()
t.click(visitor, 2, 3, assert(t.target_at(visitor, 2, 3, "airlock_button")))
t.run_ticks(2)
airlock_cycle.until_door(
    8,
    true,
    visitor,
    since,
    sealed_while(8, 5, "entry", watched, function(kpa)
        return kpa >= 100
    end)
)
assert(
    assert(t.door_at(5, 3)).bolted and not assert(t.door_at(5, 3)).open,
    "the space leaf stays bolted shut"
)
assert((airlock_cycle.pressure() or 0) >= 100, "the chamber filled before home opened")

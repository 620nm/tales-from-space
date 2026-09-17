-- North-south lock, three buttons, charged chamber: the departures shape.
-- Station north holds air, void lies south, and a chamber button stands
-- between the leaves -- the third knock the old count refused, faulting
-- every press. The chamber starts charged and vents through the open
-- exterior leaf; by the press the lock must read pump, shut space, fill,
-- and open home. A program that latched its first read would skip the
-- fill and open home onto vacuum instead.
local AIRLOCK = [==[
(
    name: "Southface Airlock",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        ' ': (composition: (substrate: Some("space"))), '.': (composition: (components: [(component: "station_base")])), '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
        'A': (composition: (components: [(component: "station_base")]), fixture: Some(Apc)),
        'o': (composition: (components: [(component: "station_base")]), fixture: Some(Outlet)),
    },
    rows: [
        "##############", "#.##########.#", "###...GAo#####",
        "#####.########", "#####.########", "#####.########",
        "#####.########", "#####.########", "              ",
        "              ",
    ],
    blends: {
        "vacuum": (temperature_k: 293.15, amount: per_tile),
        "breathable_air": (rows: [("o2", 8.730437114532117), ("n2", 32.84307295466844)], temperature_k: 293.15, amount: per_tile),
        "supply": (rows: [("o2", 392.86967015394526), ("n2", 1477.93828296008)],
            temperature_k: 293.15, amount: per_tile),
    },
    painted: [(3, 2, "breathable_air"), (4, 2, "breathable_air"),
        (5, 2, "breathable_air"), (6, 2, "breathable_air"),
        (7, 2, "breathable_air"), (8, 2, "breathable_air"),
        (5, 4, "breathable_air"), (5, 5, "breathable_air"),
        (5, 6, "breathable_air"), (5, 3, "breathable_air"),
        (5, 7, "breathable_air"), (1, 1, "supply"), (12, 1, "vacuum")],
    structures: [
        (3, 2, "player_spawn", { "jobs": "assistant" }),
        (4, 2, "player_spawn", { "jobs": "engineer" }),
        (5, 4, "access_point", { "network_1": "network_card", "file.airlock_controller": true, "program.controller": "airlock_controller", "mount": "east" }),
        (5, 2, "airlock_button", { "mount": "north" }),
        (5, 6, "airlock_button", { "mount": "west" }),
        (5, 6, "utility_outlet_port"),
        (5, 8, "airlock_button", { "mount": "northwest" }),
        (5, 3, "airlock", { "bolted": true }),
        (5, 7, "airlock", { "open": true, "bolted": true }),
        (5, 5, "airlock_pump", { "dir": "north" }),
        (1, 1, "passive_vent", { "channel": "l4", "pipe": "south" }),
        (12, 1, "passive_vent", { "channel": "l2", "pipe": "south" }),
    ],
    links: [
        (5, 4, 5, 2), (5, 4, 5, 3), (5, 4, 5, 5),
        (5, 4, 5, 6), (5, 4, 5, 7), (5, 4, 5, 8),
    ],
    networks: [
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 6, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 7, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 8, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 8, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 4, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 5, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 5, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 6, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 6, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 7, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 7, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "pipe", channel: "l4", kind: "standard", facing: 15),
        (x: 2, y: 2, network: "pipe", channel: "l4", kind: "standard", facing: 15),
        (x: 3, y: 2, network: "pipe", channel: "l4", kind: "standard", facing: 15),
        (x: 4, y: 2, network: "pipe", channel: "l4", kind: "standard", facing: 15),
        (x: 5, y: 2, network: "pipe", channel: "l4", kind: "standard", facing: 15),
        (x: 5, y: 3, network: "pipe", channel: "l4", kind: "standard", facing: 15),
        (x: 5, y: 4, network: "pipe", channel: "l4", kind: "standard", facing: 15),
        (x: 12, y: 2, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 11, y: 2, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 10, y: 2, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 9, y: 2, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 8, y: 2, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 7, y: 2, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 6, y: 2, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 5, y: 2, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 5, y: 3, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 5, y: 4, network: "pipe", channel: "l2", kind: "standard", facing: 15),
    ],
    items: [],
)
]==]
local airlock_cycle = require("@helpers/airlock_cycle")
t.set_breathing(false)
t.world(AIRLOCK, 0)
t.join("assistant")
local visitor = t.join("engineer")
t.run_ticks(20)

local CHAMBER = { { 5, 4 }, { 5, 5 }, { 5, 6 } }
local function chamber()
    local parts = {}
    for _, tile in ipairs(CHAMBER) do
        table.insert(parts, tostring(t.room_pressure(tile[1], tile[2])))
    end
    return table.concat(parts, ",")
end

-- The charged room breathes out through the open south leaf.
local vented = false
for _ = 1, 150 do
    if (t.room_pressure(5, 6) or 0) < 50 then
        vented = true
        break
    end
    t.run_ticks(10)
end
assert(vented, "the chamber vents through the open leaf: " .. chamber())

local function sealed_while(
    opening: { number },
    partner: { number },
    step: string,
    watched: number,
    admits: (number) -> boolean
)
    local checked = false
    return function()
        local d = assert(t.door_at(opening[1], opening[2]))
        if d.open or d.moving then
            local p = assert(t.door_at(partner[1], partner[2]))
            assert(
                not p.open and not p.moving and p.bolted,
                "door " .. partner[1] .. "," .. partner[2] .. " is bolted shut before "
                    .. opening[1] .. "," .. opening[2] .. " moves"
            )
            if not checked then
                checked = true
                for _, tile in ipairs(CHAMBER) do
                    assert(
                        admits(assert(t.room_pressure(tile[1], tile[2]))),
                        tostring(step) .. ": chamber ready as the home leaf moves: " .. chamber()
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

-- Station-side press: the south leaf shuts, the room fills, home opens.
local since = airlock_cycle.mark()
local watched = airlock_cycle.watches()
t.click(visitor, 5, 2, assert(t.target_at(visitor, 5, 2, "airlock_button")))
t.run_ticks(2)
airlock_cycle.until_door(
    5,
    true,
    visitor,
    since,
    sealed_while({ 5, 3 }, { 5, 7 }, "entry", watched, function(kpa)
        return kpa >= 100
    end),
    nil,
    3
)
assert(
    assert(t.door_at(5, 7)).bolted and not assert(t.door_at(5, 7)).open,
    "the space leaf stays bolted shut"
)
assert((airlock_cycle.pressure() or 0) >= 100, "the chamber filled before home opened")

-- What a tile opens breathing: the pack's airs by inheritance, and the
-- refusal when a map names air it never declared (docs/ATMOS.md).
--
-- `cold_outpost.ron` paints nothing, so every tile breathes what its
-- exposure inherits: indoors the ideal default, outdoors the map's cold
-- sky. Both are 21/79 at one atmosphere, told apart by temperature.

t.world_file("cold_outpost.ron", 7, "free_build")

local IDEAL_K = 293.15
local COLD_K = 259.15
local ONE_ATM_KPA = 101.325

local function near(actual: number, want: number, slack: number, what: string)
    assert(math.abs(actual - want) < slack, what .. ": " .. actual .. " vs " .. want)
end

local function o2_share(x: number, y: number): number
    local gas = assert(t.room_gas(x, y))
    local o2 = gas.o2 or 0.0
    local n2 = gas.n2 or 0.0
    assert(o2 + n2 > 0, "the tile holds air")
    return o2 / (o2 + n2)
end

-- Indoors, unpainted: the ideal default.
near(assert(t.room_temperature(4, 3)), IDEAL_K, 0.01, "a room opens at 20 C")
near(assert(t.room_pressure(4, 3)), ONE_ATM_KPA, 0.5, "at one atmosphere")
near(o2_share(4, 3), 0.21, 1e-6, "21% of it oxygen")

-- Outdoors, unpainted: the map's own cold sky, same rule.
near(assert(t.room_temperature(0, 0)), COLD_K, 0.01, "outside opens at -14 C")
near(assert(t.room_pressure(0, 0)), ONE_ATM_KPA, 0.5, "topped up to one atmosphere")
near(o2_share(0, 0), 0.21, 1e-6, "the same 21/79 as indoors")

-- A tile naming a blend the map never declared refuses the world.
local ok, why = pcall(function()
    t.world(
        [==[(
    name: "undeclared air",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    rows: ["."],
    structures: [(0, 0, "player_spawn")],
    painted: [(0, 0, "no_such_blend")],
)]==],
        0
    )
end)
assert(not ok, "a painted unknown blend boots")
assert(
    string.find(tostring(why), "does not declare", 1, true) ~= nil,
    "saying what it is: " .. tostring(why)
)

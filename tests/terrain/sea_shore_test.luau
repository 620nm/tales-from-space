-- A sea stands in its bed one film under the land beside it: it does not
-- flood the shore, and water spilled on the shore runs in. A body in it reads
-- about double the air pressure, under tg's warning band, and takes no harm
-- (the engine's docs/matter-world/beds.md).
--
-- Columns 0-3 are sand, 4-7 sea, under the `warm_outdoors` sky. The spill is
-- 20 L on the shore; the body stands in the sea.
t.world(
    [==[(
    name: "sea shore",
    tags: ["terrestrial", "warm_outdoors"],
    environment: (kind: Exact(terrestrial)),
    legend: {
        'a': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sand_ground"), components: [])),
        'w': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sea_water"), components: [])),
    },
    levels: [
        (
            rows: [
                "aaaawwww",
                "aaaawwww",
                "aaaawwww",
                "aaaawwww",
                "aaaawwww",
                "aaaawwww",
                "aaaawwww",
            ],
            structures: [(6, 3, "player_spawn")],
            painted: [(3, 1, "spill")],
        ),
    ],
    blends: {
        "spill": (rows: [("water", 1110.0)], temperature_k: 293.15, amount: total),
    },
)]==],
    0,
    "free_build"
)
t.set_breathing(false)

local matter_look = require("@helpers/matter_look")

local ONE_ATMOSPHERE_KPA = 101.325
local WARNING_HIGH_PRESSURE_KPA = 325 -- tg: code/__DEFINES/atmospherics/atmos_core.dm

local function litres(x: number, y: number): number
    local liquid = t.room_liquid(x, y)
    return if liquid then liquid.water or 0 else 0
end

local p = t.join()
local health = t.health(p).health
t.run_ticks(4)

assert(math.abs(litres(5, 3) - 1500) < 1, "a sea tile stands 1.5 m deep, got " .. litres(5, 3) .. " L")
local open_water = assert(matter_look.find(p, 5, 3, "puddle", 6), "deep water draws the sea's rung")
assert(open_water.rung == 6, "the top of the water ladder")
assert(#matter_look.parts(p, 5, 3, "puddle") == 1, "and the sea is not also a puddle")

t.run_seconds(120)

assert(litres(3, 6) < 1, "the sea stays in its bed: the shore far from the spill is dry, got " .. litres(3, 6))
assert(litres(3, 1) < 5, "the spill ran in and left a film, got " .. litres(3, 1) .. " L")

local kpa = assert(t.room_pressure(6, 3))
assert(kpa > 1.5 * ONE_ATMOSPHERE_KPA, "a deep tile reads the air squeezed into half its shell, got " .. kpa)
assert(kpa < WARNING_HIGH_PRESSURE_KPA, "the body's own tile reads under the warning band, got " .. kpa)
assert(t.health(p).health == health, "and takes no pressure effect")

-- The cryo-hydrocarbon world's sea fills its bed 1.5 m deep with liquid
-- methane and ethane at 94 K, 70:30 by mole, and stands there: ten minutes
-- on it has not evaporated, warmed or run onto the shore beside it
-- (content/terrain.luau `hydrocarbon_sea`: no evaporation, walked to its fill).
--
-- Columns 0-2 are blank ice shore, 3-6 sea, under the upper air.
t.world(
    [==[(
    name: "methane sea",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), surface_temperature_k: Exact(94.0)),
    legend: {
        'o': (outdoors: true, composition: ()),
        'w': (outdoors: true, composition: (substrate: Named("ground"), material: Named("hydrocarbon_sea"), components: [])),
    },
    levels: [
        (
            rows: [
                "ooowwww",
                "ooowwww",
                "ooowwww",
            ],
            structures: [(1, 1, "player_spawn")],
        ),
    ],
)]==],
    0,
    "free_build"
)
assert(t.environment().id == "cryo_hydrocarbon", "a 94 K map rolls the cryo-hydrocarbon world")

local SURFACE_K = 94.0 -- content/environments/cryo_hydrocarbon.luau
local DEPTH_L = 1500 -- 1.5 m over a 1 m tile (content/terrain.luau)
-- The methane share of the sea's volume at 70:30 by mole, from the molar
-- volumes content/blends/hydrocarbon_sea.luau adds: 0.7 * 16.043 / 0.42
-- over that plus 0.3 * 30.069 / 0.65.
local METHANE_ML = 0.7 * 16.043 / 0.42
local ETHANE_ML = 0.3 * 30.069 / 0.65
local METHANE_SHARE = METHANE_ML / (METHANE_ML + ETHANE_ML)

local function liters(x: number, y: number, key: string): number
    local liquid = t.room_liquid(x, y)
    return if liquid then liquid[key] or 0 else 0
end

local function sea_stands(when: string)
    for y = 0, 2 do
        for x = 3, 6 do
            local where = when .. " (" .. x .. ", " .. y .. ")"
            local methane = liters(x, y, "methane")
            local ethane = liters(x, y, "ethane")
            local depth = methane + ethane
            assert(math.abs(depth - DEPTH_L) < 1, "1.5 m deep " .. where .. ": " .. depth)
            local share = methane / (methane + ethane)
            assert(math.abs(share - METHANE_SHARE) < 0.01, "70:30 " .. where .. ": " .. share)
            local kelvin = assert(t.room_temperature(x, y))
            assert(math.abs(kelvin - SURFACE_K) < 0.1, "at 94 K " .. where .. ", got " .. kelvin)
        end
        for x = 0, 2 do
            local wet = liters(x, y, "methane") + liters(x, y, "ethane")
            assert(wet < 1e-3, "the shore stays dry " .. when .. " at x " .. x .. ": " .. wet)
        end
    end
end

t.run_ticks(4)
sea_stands("at once")
t.run_seconds(600)
sea_stands("ten minutes on")

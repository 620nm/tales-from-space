-- The cryo-hydrocarbon world's ground stands at 94 K under its own sky, and
-- the methane in that sky stays gas: the upper air's 7.5 kPa is under
-- methane's 17.15 kPa saturation at 94 K, so ten minutes outdoors condense
-- none of it (content/blends/cryo_air.luau has the arithmetic).
--
-- A free-build map pinned to 94 K rolls the world; every tile is blank
-- outdoor ground over the generated sheet-ice surface. Nobody joins, so no
-- body warms a tile.
local atmos_cell = require("@helpers/atmos_cell")

local SURFACE_K = 94.0 -- content/environments/cryo_hydrocarbon.luau
local TOTAL_KPA = 150.0 -- content/blends/cryo_air.luau
local METHANE_PA = 7500.0 -- content/blends/cryo_air.luau
local METHANE_MOLES = atmos_cell.cell_moles(atmos_cell.density_mol_per_m3(METHANE_PA, SURFACE_K))

t.world(
    [==[(
    name: "cryo ground",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), surface_temperature_k: Exact(94.0)),
    legend: {
        'o': (outdoors: true, composition: ()),
    },
    levels: [
        (
            rows: [
                "ooooo",
                "ooooo",
                "ooooo",
            ],
            structures: [(2, 1, "player_spawn")],
        ),
    ],
)]==],
    0,
    "free_build"
)

local sky = t.environment()
assert(sky.id == "cryo_hydrocarbon", "a 94 K map rolls the cryo-hydrocarbon world, got " .. sky.id)
assert(assert(assert(sky.profile).atmosphere).blend == "cryo_air", "under its upper air")
local blank = assert(t.composition(2, 1))
assert(
    blank.resolved_substrate == "ice_floor",
    "a blank tile stands on the sheet-ice surface, got " .. tostring(blank.resolved_substrate)
)

local PROBES = { { x = 0, y = 0 }, { x = 2, y = 1 }, { x = 4, y = 2 } }

local function still_cold_and_dry(when: string)
    for _, at in PROBES do
        local where = when .. " (" .. at.x .. ", " .. at.y .. ")"
        local air_k = assert(t.room_temperature(at.x, at.y))
        assert(math.abs(air_k - SURFACE_K) < 0.01, "the air is 94 K " .. where .. ": " .. air_k)
        local deck_k = assert(t.deck(at.x, at.y), "the ground has a deck " .. where).temperature
        assert(math.abs(deck_k - SURFACE_K) < 0.01, "ground at 94 K " .. where .. ": " .. deck_k)
        local kpa = assert(t.room_pressure(at.x, at.y))
        assert(math.abs(kpa - TOTAL_KPA) < 0.5, "at 1.5 bar " .. where .. ", got " .. kpa)
        local methane = (assert(t.room_gas(at.x, at.y)).methane or 0)
        assert(
            math.abs(methane - METHANE_MOLES) < METHANE_MOLES * 0.01,
            "the methane is all gas " .. where .. ": " .. methane .. " of " .. METHANE_MOLES
        )
        local liquid = t.room_liquid(at.x, at.y)
        local puddle = if liquid then liquid.methane or 0 else 0
        assert(puddle < 1e-6, "and none of it rains out " .. where .. ", got " .. puddle .. " L")
    end
end

t.run_ticks(4)
still_cold_and_dry("at once")
t.run_seconds(600)
still_cold_and_dry("ten minutes on")

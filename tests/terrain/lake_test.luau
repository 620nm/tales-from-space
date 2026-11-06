-- A lake is water standing in a bed with nothing behind it: a cut lets it
-- out, and a sun boils it (the engine's docs/matter-world/beds.md).
--
-- Column 0 is a meter of lake with a dry 2 m trench beside it, sand past that.
-- Columns 5-7 are a lake with no way out, under a sky set blazing below.
t.world(
    [==[(
    name: "lake",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), surface_temperature_k: Exact(293.15)),
    legend: {
        'a': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sand_ground"), components: [])),
        'l': (outdoors: true, composition: (substrate: Named("ground"), material: Named("lake_water"), components: [])),
        'd': (outdoors: true, composition: (substrate: Named("ground"), material: Named("dug_sand"), components: [])),
    },
    levels: [
        (
            rows: [
                "lldaalll",
                "lldaalll",
                "lldaalll",
            ],
            structures: [(3, 1, "player_spawn")],
        ),
    ],
)]==],
    0,
    "free_build"
)
t.set_breathing(false)

local function liters(x: number, y: number): number
    local liquid = t.room_liquid(x, y)
    return if liquid then liquid.water or 0 else 0
end

t.join()
t.run_ticks(4)
assert(math.abs(liters(0, 1) - 1000) < 1, "a lake tile stands a meter deep, got " .. liters(0, 1))
assert(liters(2, 1) < 1, "the trench starts dry")

t.run_seconds(240)
assert(liters(0, 1) < 800, "the cut drains the lake, got " .. liters(0, 1))
assert(liters(2, 1) > 200, "into the trench, got " .. liters(2, 1))
assert(liters(4, 1) < 5, "and past a sill it cannot top, not over the land, got " .. liters(4, 1))

-- The far lake has no way out. This sun brings it to the boil, where it
-- stays, and it leaves as steam.
local before = liters(6, 1)
t.set_environment({ sink_k = 293.15, insolation = 5e8 })
t.run_seconds(600)
local lake_k = assert(t.room_temperature(6, 1))
assert(lake_k > 373, "the sun brings the lake to the boil, got " .. lake_k .. " K, " .. liters(6, 1) .. " L")
assert(liters(6, 1) < before - 10, "and a heated lake boils away, from " .. before .. " to " .. liters(6, 1) .. " at " .. lake_k .. " K")
local steam = t.room_gas(6, 1)
assert(steam and (steam.water or 0) > 0, "into steam over it")

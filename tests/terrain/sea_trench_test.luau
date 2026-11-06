-- A trench cut from a sea fills, stands full and spills nowhere: the sea walks
-- back to its ideal, so what ran out arrives again for free (the engine's
-- docs/matter-world/ideal.md).
--
-- Columns 0-2 are sea, 3-4 a trench deeper than the sea, 5-6 sand.
t.world(
    [==[(
    name: "sea trench",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), surface_temperature_k: Exact(293.15)),
    legend: {
        'a': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sand_ground"), components: [])),
        'w': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sea_water"), components: [])),
        'd': (outdoors: true, composition: (substrate: Named("ground"), material: Named("dug_sand"), components: [])),
    },
    levels: [
        (
            rows: [
                "wwwddaa",
                "wwwddaa",
                "wwwddaa",
            ],
            structures: [(6, 1, "player_spawn")],
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
assert(liters(4, 1) < 1, "the trench starts dry, got " .. liters(4, 1))

t.run_seconds(600)
assert(liters(4, 1) > 1850, "the far end fills toward the sea's level, got " .. liters(4, 1) .. " L")
assert(liters(0, 1) > 1350, "the sea stays near full while it feeds it, got " .. liters(0, 1) .. " L")
assert(liters(5, 1) < 1, "and the land stays dry, got " .. liters(5, 1) .. " L")

local filled = liters(4, 1)
t.run_seconds(60)
assert(liters(4, 1) > filled - 1, "the trench stays full, from " .. filled .. " to " .. liters(4, 1))

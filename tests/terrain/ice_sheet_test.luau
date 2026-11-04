-- A frozen sheet in a bed draws as ice, melts under enough heat, and stays
-- melted: nothing walks it back to ice while the heat holds. A warm map
-- cannot lay it at all (the engine's docs/content-schema/terrain.md). A sea
-- on a world this cold is the same ice, at its own depth. Ice laid as ground
-- stands on its profile's own floor (content/terrain.luau `sheet_ice`).
t.world(
    [==[(
    name: "ice sheet",
    tags: ["terrestrial"],
    environment: (kind: Exact(terrestrial)),
    legend: {
        'a': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sand_ground"), components: [])),
        'i': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sheet_ice"), components: [])),
        's': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sea_water"), components: [])),
        'f': (outdoors: true, composition: (material: Named("sheet_ice"), components: [])),
    },
    levels: [
        (
            rows: [
                "aaiii",
                "aaiii",
                "aaiii",
                "fasss",
            ],
            structures: [(0, 1, "player_spawn")],
        ),
    ],
)]==],
    0,
    "free_build"
)
t.set_breathing(false)

local matter_look = require("@helpers/matter_look")

local ICE = "#D4EFF7" -- content/substances/water.luau

local p = t.join()
t.run_ticks(4)

local sheet = assert(matter_look.find(p, 3, 1, "crystalline", 3), "a metre of ice draws the sheet rung")
assert(sheet.tint == ICE, "in ice's own colour, got " .. sheet.tint)
assert(#matter_look.parts(p, 3, 1, "crystalline") == 1, "and only the sheet")
assert(matter_look.find(p, 3, 3, "crystalline", 3), "a frozen sea is the same sheet")
local ice_ground = assert(t.composition(0, 3))
assert(ice_ground.resolved_substrate == "ice_floor", "ice ground stands on the ice floor, got " .. tostring(ice_ground.resolved_substrate))

t.set_environment({ sink_k = 259.15, insolation = 1e7 })
t.run_seconds(600)
assert(matter_look.top_rung(p, 3, 1, "crystalline") == 0, "the sun melts the sheet")
local melt = t.room_liquid(3, 1)
assert(melt and (melt.water or 0) > 0, "to water standing in its bed")
t.run_seconds(120)
assert(matter_look.top_rung(p, 3, 1, "crystalline") == 0, "and it stays melted")

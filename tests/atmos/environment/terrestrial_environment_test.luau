local composition = require("@helpers/composition")

local ui_controls = require("@helpers/ui_controls")

-- The authored outpost starts cold outdoors and warm behind an operable door.
t.world_file("cold_outpost.ron", 7, "free_build")
local sky = t.environment()
local atmosphere = assert(assert(sky.profile).atmosphere)
assert(sky.id == "cold_outdoors")
assert(sky.kind == "terrestrial")
assert(atmosphere.blend == "refrigerated_air")
assert(composition.bare(0, 0, "ground"))
assert(composition.bare(8, 3, "ground"))
assert(composition.bare(9, 5, "space"), "authored vacuum stays vacuum")
assert(math.abs(assert(t.room_temperature(0, 0)) - 259.15) < 0.01)
assert(math.abs(assert(t.room_temperature(4, 3)) - 293.15) < 0.01)
assert(assert(t.room_pressure(0, 0)) > 100)
assert(not assert(t.door_at(6, 3)).open)

local p = t.join()
t.run_ticks(10)
t.move(p, "east")
t.run_ticks(5)
t.click(p, 6, 3, t.target_at(p, 6, 3))
t.run_ticks(15)
assert(assert(t.door_at(6, 3)).open, "the outpost's APC supplies its door")
t.run_ticks(60)
assert(assert(t.room_temperature(4, 3)) < 293.15, "outside air cools the opened room")

-- Building a deck on land uses the ordinary material construction path.
t.world(
    [==[(
    name: "ground construction", tags: ["terrestrial"],
    legend: { '#': (composition: (components: [(component: "station_base"), (component: "wall")])), '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])), 'g': (composition: (substrate: Some("ground")), outdoors: true) },
    rows: ["###", "#.g", "###"], structures: [(1, 1, "player_spawn")],
    items: [(1, 1, "floor_tile")],
)]==],
    7
)
local builder = t.join("assistant")
t.run_ticks(2)
t.click(builder, 1, 1, t.target_at(builder, 1, 1, "floor_tile"))
t.run_ticks(2)
ui_controls.build(builder, "floor_tile", "ground", 2, 1)
t.run_ticks(40)
assert(
    composition.matches(2, 1, { "station_base" }),
    "a new deck can be laid on ground: " .. table.concat(t.messages(builder), " | ")
)
ui_controls.build(builder, "floor_tile", "plating", 2, 1)
t.run_ticks(15)
assert(composition.matches(2, 1, { "station_base", "floor_tiles" }), "the deck can be tiled normally")

assert(t.set_composition(2, 1, "bare"))
assert(composition.bare(2, 1, "ground"), "removing the deck retains its authored ground")
assert(t.set_composition(2, 1, "plating"))
assert(assert(t.composition(2, 1)).resolved_substrate == "ground", "replacing the deck retains ground")

-- The authored outpost starts cold outdoors and warm behind an operable door.
t.world_file("cold_outpost.ron", 7, "free_build")
local sky = t.environment()
assert(sky.id == "cold_outdoors")
assert(sky.kind == "terrestrial")
assert(sky.profile.atmosphere.blend == "refrigerated_air")
assert(t.turf(0, 0) == "ground")
assert(t.turf(8, 3) == "ground")
assert(t.turf(9, 5) == "space", "authored vacuum stays vacuum")
assert(math.abs(t.room_temperature(0, 0) - 259.15) < 0.01)
assert(math.abs(t.room_temperature(4, 3) - 293.15) < 0.01)
assert(t.room_pressure(0, 0) > 100)
assert(not t.door_at(6, 3).open)

local p = t.join()
t.run_ticks(10)
t.move(p, "east")
t.run_ticks(5)
t.click(p, 6, 3, t.target_at(6, 3))
t.run_ticks(15)
assert(t.door_at(6, 3).open, "the outpost's APC supplies its door")
t.run_ticks(60)
assert(t.room_temperature(4, 3) < 293.15, "outside air cools the opened room")

-- Building a deck on land uses the ordinary material construction path.
t.world([==[(
    name: "ground construction", tags: ["terrestrial"],
    legend: { '#': (turf: Wall), '.': (turf: Floor), 'g': (turf: Ground, outdoors: true) },
    rows: ["###", "#.g", "###"], spawns: [(1, 1)],
    items: [(1, 1, "floor_tile")],
)]==], 7)
local builder = t.join("assistant")
t.run_ticks(2)
t.click(builder, 1, 1, t.target_at(1, 1, "floor_tile"))
t.run_ticks(2)
t.build(builder, "floor_tile", "ground", 2, 1)
t.run_ticks(40)
assert(t.turf(2, 1) == "plating", "a new deck can be laid on ground: " .. table.concat(t.messages(builder), " | "))
t.build(builder, "floor_tile", "plating", 2, 1)
t.run_ticks(15)
assert(t.turf(2, 1) == "floor", "the deck can be tiled normally")

assert(t.set_turf(2, 1, "space"))
assert(t.turf(2, 1) == "space", "literal assignment does not substitute ground")
assert(t.set_turf(2, 1, "ground"))
assert(t.turf(2, 1) == "ground")

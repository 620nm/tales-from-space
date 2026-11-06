local clock = require("@helpers/clock")
local composition = require("@helpers/composition")

local ui_controls = require("@helpers/ui_controls")

-- The cold fixture starts outdoors and warm behind an operable door.
t.world_file("cold_outpost.ron", 7, "free_build")
local sky = t.environment()
local atmosphere = assert(assert(sky.profile).atmosphere)
assert(sky.id == "cold_outdoors")
assert(sky.kind == "terrestrial")
assert(atmosphere.blend == "refrigerated_air")
-- A blank outdoor tile names no substrate: it stands on the generated ground,
-- so its effective substrate is the floor of the surface block's profile.
local blank = assert(t.composition(0, 0))
assert(#blank.components == 0 and blank.substrate == nil, "the blank outdoor tile authors nothing")
assert(
    blank.resolved_substrate == "ice_floor",
    "the blank tile resolves to the sheet-ice surface block's floor, got " .. tostring(blank.resolved_substrate)
)
assert(composition.bare(8, 3, "ground"))
assert(composition.bare(9, 5, "space"), "authored vacuum stays vacuum")
assert(math.abs(assert(t.room_temperature(0, 0)) - 259.15) < 0.01)
assert(math.abs(assert(t.room_temperature(4, 3)) - 293.15) < 0.01)
assert(assert(t.room_pressure(0, 0)) > 100)
assert(not assert(t.door_at(6, 3)).open)

local p = t.join()
t.run_seconds(0.5)
t.move(p, "east")
t.run_ticks(5)
t.click(p, 6, 3, assert(t.target_at(p, 6, 3)))
t.run_ticks(clock.deadline_ticks(0.6) + 3) -- tg's 0.6 s swing, plus observation
assert(assert(t.door_at(6, 3)).open, "the fixture's APC supplies its door")
t.run_seconds(3)
assert(assert(t.room_temperature(4, 3)) < 293.15, "outside air cools the opened room")

-- Building a deck on land uses the ordinary material construction path.
t.world(
    [==[(
    name: "ground construction", needs: ["gravity"],
    environment: (kind: Exact(terrestrial), surface_temperature_k: Exact(259.15)),
    legend: { '#': (composition: (components: [(component: "station_base"), (component: "wall")])), '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])), 'g': (composition: (substrate: Named("ground")), outdoors: true) },
    levels: [
        (
            rows: ["###", "#.g", "###"], structures: [(1, 1, "player_spawn")],
            items: [(1, 1, "floor_tile")],
        ),
    ],
)]==],
    7
)
local builder = t.join("assistant")
t.run_ticks(2)
t.click(builder, 1, 1, assert(t.target_at(builder, 1, 1, "floor_tile")))
t.run_ticks(2)
ui_controls.build(builder, "floor_tile", "ground", 2, 1)
t.run_seconds(2)
assert(
    composition.matches(2, 1, { "station_base" }),
    "a new deck can be laid on ground: " .. table.concat(t.messages(builder), " | ")
)
ui_controls.build(builder, "floor_tile", "plating", 2, 1)
t.run_seconds(0.75)
assert(composition.matches(2, 1, { "station_base", "floor_tiles" }), "the deck can be tiled normally")

-- The bare preset writes the inherited substrate: the tile then stands on
-- the ground the environment generates, and shows that ground's floor.
assert(t.set_composition(2, 1, "bare"))
t.run_ticks(2)
local cleared = assert(t.composition(2, 1))
assert(#cleared.components == 0 and cleared.substrate == nil, "the bare preset clears the deck: " .. composition.describe(2, 1))
local shown = composition.seen_sprites(builder, 2, 1).substrates[1]
assert(shown == "ice_floor-0", "the cleared tile shows the generated ice floor, got " .. tostring(shown))
local ice_face = t.seen_ground(builder, 2, 1)
assert(#ice_face == 1 and ice_face[1].look == "ice_shell", "and the ice sheet face over it")
assert(ice_face[1].tint == "#D4EFF7", "in ice's own color, got " .. ice_face[1].tint) -- content/substances/water.luau
assert(t.set_composition(2, 1, "plating"))
assert(composition.matches(2, 1, { "station_base" }), "a deck can be laid again over the generated ground")

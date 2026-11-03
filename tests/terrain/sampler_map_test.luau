-- The shipped terrain sampler (maps/terrain_sampler.ron, written by
-- tools/terrain-sampler.mjs) boots: sand and soil draw a ground face, the
-- sea stands 1.5 m deep, and the cliff south of the spawn stops a body.
-- Spawn (36, 35) is sand; the sea starts east of x = 44, the cliff at y = 38.
-- Booting under the default mode's warm sky is `lunatic-server maps`'s check.
t.world_file("terrain_sampler.ron", 0, "free_build")
t.set_breathing(false)

local p = t.join()
t.run_ticks(4)

local sand = t.seen_ground(p, 36, 34)
assert(#sand == 1 and sand[1].look == "ground_shell", "sand draws the ground face")
local soil = t.seen_ground(p, 33, 35)
assert(#soil == 1 and soil[1].look == "ground_shell", "soil draws the ground face")

local sea = t.room_liquid(58, 10)
assert(sea and math.abs((sea.water or 0) - 1500) < 1, "a sea tile stands 1.5 m deep")

local x0, y0 = t.pos(p)
assert(x0 == 36 and y0 == 35, "the body spawns on the shore")
for _ = 1, 4 do
    t.move(p, "south")
    t.run_seconds(0.5)
end
local x, y = t.pos(p)
assert(x == 36 and y == 37, "the cliff at y = 38 stops a body, at " .. x .. "," .. y)
local face = t.seen_ground(p, 36, 38)
assert(#face == 1 and face[1].look == "cliff_shell", "and draws the cliff face")

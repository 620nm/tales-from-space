-- The shipped terrain sampler (maps/terrain_sampler.ron, written by
-- tools/maps/terrain-sampler.mjs) boots: sand and soil draw a ground face, the
-- sea stands 1.5 m deep, and the cliff of half-height quartz steps south of
-- the spawn stops a walk, is climbed, and is walked along and off.
-- Spawn (36, 35) is sand; the sea starts east of x = 44, the cliff at y = 38-40.
-- Booting under the default mode's warm sky is `lunatic-server maps`'s check.
t.world_file("terrain_sampler.ron", 0, "free_build")
t.set_breathing(false)

local SILICA = "#C8C4BC" -- content/substances/ground/silica.luau

local p = t.join()
t.run_ticks(4)

local sand = t.seen_ground(p, 36, 34)
assert(#sand == 1 and sand[1].look == "ground_shell", "sand draws the ground face")
local soil = t.seen_ground(p, 33, 35)
assert(#soil == 1 and soil[1].look == "ground_shell", "soil draws the ground face")

local sea = t.room_liquid(58, 10)
assert(sea and math.abs((sea.water or 0) - 1500) < 1, "a sea tile stands 1.5 m deep")

local function step(direction: "north" | "south" | "east" | "west")
    t.move(p, direction)
    t.run_seconds(0.5)
end

local function at(x: number, y: number, why: string)
    local px, py = t.pos(p)
    assert(px == x and py == y, why .. ": at " .. px .. "," .. py)
end

at(36, 35, "the body spawns on the shore")
step("south")
step("south")
step("south")
at(36, 37, "the cliff at y = 38 stops a walk")
local face = t.seen_ground(p, 36, 38)
assert(#face == 1 and face[1].look == "cliff_shell", "and draws the step's cliff face")
assert(face[1].tint == SILICA, "in quartz's colour, got " .. face[1].tint)

-- The refused walk became a climb: two seconds later the body is on top.
t.run_seconds(2.5)
at(36, 38, "the body climbs onto the cliff")
step("south")
step("south")
at(36, 40, "and walks along its top")
step("south")
at(36, 41, "and steps down off it onto the sand")

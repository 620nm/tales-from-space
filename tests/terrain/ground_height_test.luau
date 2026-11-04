-- A column's ground `height` raises generated ground into the map's levels
-- (the engine's docs/mapping/generated-ground.md). Under `warm_outdoors`
-- soil tops each column; a height-1 column hinted `rock` is a full block of
-- that world's bedrock (silica_ground, content/environments/warm_outdoors.luau)
-- on level 0 itself, z = height - 1: a body cannot walk into it and it draws
-- the quartz face where the soil beside it draws soil. A height more than one
-- over the top level is refused by name.
local MAP = [==[(
    name: "ground height",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), surface_temperature_k: Exact(293.15)),
    legend: {
        '.': (outdoors: true, composition: ()),
    },
    ground: (legend: { '^': (height: %d, material: Some(Role("rock"))) }, rows: ["...^..", "...^..", "...^.."]),
    levels: [
        (
            rows: ["......", "......", "......"],
            structures: [(1, 1, "player_spawn")],
        ),
    ],
)]==]

local SOIL = "#5C4033" -- content/substances/ground/soil.luau
local SILICA = "#C8C4BC" -- content/substances/ground/silica.luau

-- Height 2 needs a level 1 above this one-level map: the map does not load.
local ok, why = pcall(function()
    t.world(string.format(MAP, 2), 0, "free_build")
end)
assert(not ok, "a height over the top level plus one refuses the map")
assert(
    string.find(tostring(why), "above the top level", 1, true) ~= nil,
    "and the refusal says why: " .. tostring(why)
)

t.world(string.format(MAP, 1), 0, "free_build")
t.set_breathing(false)
local p = t.join()
t.run_ticks(4)

local function at(x: number, y: number, why_here: string)
    local px, py = t.pos(p)
    assert(px == x and py == y, why_here .. ": at " .. px .. "," .. py)
end

local beside = t.seen_ground(p, 2, 1)
assert(#beside == 1 and beside[1].tint == SOIL, "a blank tile stands on the soil surface")
local ridge = t.seen_ground(p, 3, 1)
assert(#ridge == 1 and ridge[1].look == "ground_shell", "the raised column draws a ground face")
assert(ridge[1].tint == SILICA, "of the world's bedrock, got " .. ridge[1].tint)

t.move(p, "east")
t.run_seconds(0.5)
at(2, 1, "the walk to the ridge")
t.move(p, "east")
t.run_seconds(0.5)
at(2, 1, "a raised block of ground stops a body")

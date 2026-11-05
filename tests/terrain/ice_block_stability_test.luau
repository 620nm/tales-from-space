-- A block stands under every world a map can roll, or the map does not load
-- (the engine's docs/mapping/generated-ground.md). Ice bedrock
-- (content/blends/ice_bedrock.luau) names its water solid, so a warm map
-- (293.15 K, `warm_outdoors`) that hints a column of it is refused, naming
-- the block's tile and the blend; the same map pinned at 94 K rolls
-- `cryo_hydrocarbon`, where ice is the bedrock, and loads.
local MAP = [==[(
    name: "ice block stability",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), surface_temperature_k: Exact(%s)),
    legend: {
        '.': (outdoors: true, composition: ()),
    },
    ground: (legend: { 'i': (material: Some(Blend("ice_bedrock"))) }, rows: ["...", "..i", "..."]),
    levels: [
        (
            rows: ["...", "...", "..."],
            structures: [(1, 1, "player_spawn")],
        ),
    ],
)]==]

local ok, why = pcall(function()
    t.world(string.format(MAP, "293.15"), 0, "free_build")
end)
assert(not ok, "ice bedrock where it would melt refuses the map")
local said = tostring(why)
assert(string.find(said, "ice_bedrock", 1, true) ~= nil, "the refusal names the blend: " .. said)
assert(string.find(said, "(2, 1)", 1, true) ~= nil, "and the block's tile: " .. said)
assert(string.find(said, "cannot stand", 1, true) ~= nil, "and says why: " .. said)

t.world(string.format(MAP, "94.0"), 0, "free_build")
assert(t.environment().id == "cryo_hydrocarbon", "a 94 K map rolls the cryo-hydrocarbon world")

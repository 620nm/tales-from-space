local ignition_room = require("@helpers/ignition_room")

-- A MEADOW FIRE WALKS THE GRASS AND LEAVES BARE GROUND.
--
-- Three rows of meadow and one of moss on open soil under a warm sky
-- (`warm_outdoors`, whose air refills). A struck burner lights the grass
-- the player stands in, and is snuffed: nothing else is a source.
--
-- * The grass and moss draw their looks before the fire.
-- * The fire spreads tile to tile: the far end of the meadow and the moss
--   latch after the tile that was lit, and burn.
-- * Every plant tile ends bare: no grass or moss drawn, the soil face still
--   there, and the fire's ash on it.
-- * With nothing left to burn, every latch lets go.
local GRASS_G_PER_M2 = 300.0 -- content/blends/meadow.luau
local MOSS_G_PER_M2 = 200.0 -- content/blends/moss_carpet.luau
local PLANT_MOLAR_MASS = 162.14
local TILE_HEIGHT_M = 3.0
local AIR_N = 101325.0 / (8.314 * 293.15)
local ASH = "#515151" -- content/substances/ash.luau

local ROWS = { ".mmmmm", ".mmmmm", ".mmmmm", ".ooooo" }
-- The player spawns on (1, 1), in the grass.
local LIT_KEY = "1:1"
local FAR_GRASS_KEY = "5:1"
local FAR_MOSS_KEY = "5:3"

local function plant_blend(id: string, substance: string, grams: number): string
    return string.format(
        '"%s": (rows: [("o2", %.6f), ("n2", %.6f), ("%s:solid", %.6f)], temperature_k: 293.15, amount: per_m3)',
        id,
        AIR_N * 0.21,
        AIR_N * 0.79,
        substance,
        grams / PLANT_MOLAR_MASS / TILE_HEIGHT_M
    )
end

local painted: { string } = {}
local plants: { { x: number, y: number, look: string } } = {}
for y, row in ipairs(ROWS) do
    for x = 1, #row do
        local glyph = string.sub(row, x, x)
        if glyph ~= "." then
            local blend = if glyph == "m" then "meadow" else "moss_carpet"
            local look = if glyph == "m" then "grass" else "moss"
            table.insert(painted, string.format('(%d, %d, "%s")', x - 1, y - 1, blend))
            table.insert(plants, { x = x - 1, y = y - 1, look = look })
        end
    end
end
local quoted: { string } = {}
for _, row in ipairs(ROWS) do
    table.insert(quoted, string.format("%q", row))
end

t.world(
    string.format(
        [==[(
    name: "meadow fire",
    tags: ["terrestrial", "warm_outdoors"],
    environment: (kind: Exact(terrestrial)),
    legend: {
        '.': (outdoors: true, composition: (substrate: Named("ground"), material: Named("soil_ground"), components: [])),
        'm': (outdoors: true, composition: (substrate: Named("ground"), material: Named("soil_ground"), components: [])),
        'o': (outdoors: true, composition: (substrate: Named("ground"), material: Named("soil_ground"), components: [])),
    },
    levels: [
        (
            rows: [%s],
            structures: [(1, 1, "player_spawn")],
            items: [(2, 1, "burner")],
            painted: [%s],
        ),
    ],
    blends: {%s, %s},
)]==],
        table.concat(quoted, ", "),
        table.concat(painted, ", "),
        plant_blend("meadow", "grass", GRASS_G_PER_M2),
        plant_blend("moss_carpet", "moss", MOSS_G_PER_M2)
    ),
    0,
    "free_build"
)
t.set_breathing(false)
local p = t.join()
t.run_ticks(4)

local function drawn(x: number, y: number, look: string): SpecSeenMatterPart?
    for _, part in ipairs(t.seen_matter(p, x, y)) do
        if part.look == look then
            return part
        end
    end
    return nil
end

local function at(plant: { x: number, y: number }): string
    return " at " .. plant.x .. ", " .. plant.y
end

for _, plant in ipairs(plants) do
    assert(drawn(plant.x, plant.y, plant.look), plant.look .. " draws" .. at(plant))
end

-- The player stands in the grass; a struck burner in hand lights the tile
-- under it within a second (lib/ignition.luau `tend_flame`). Snuffed, it is
-- no source.
ignition_room.take_lit_burner(p, 2, 1)
local caught = ignition_room.run_until(5, 0.5, function()
    return ignition_room.latched_tiles()[LIT_KEY] ~= nil
end)
assert(caught ~= nil, "the burner lit the grass it stood over")
t.use_self(p)
t.tick()

-- Spread: the far grass and a moss tile catch behind the lit tile.
local spread = ignition_room.run_until(120, 1, function()
    local lit = ignition_room.latched_tiles()
    return lit[FAR_GRASS_KEY] ~= nil and lit[FAR_MOSS_KEY] ~= nil
end)
assert(spread ~= nil, "the fire reached the far grass and the moss")
local first: { [string]: number } = {}
for _, row in ipairs(ignition_room.latch_edges(true)) do
    local tile = ignition_room.tile_of(row)
    local tile_key = ignition_room.tile_key(tile.x, tile.y)
    if first[tile_key] == nil then
        first[tile_key] = (row :: any).seq
    end
end
assert(first[LIT_KEY] < first[FAR_GRASS_KEY], "the far grass caught after the lit tile")
assert(first[LIT_KEY] < first[FAR_MOSS_KEY], "and so did the moss")

-- Burn-out: no plant is drawn anywhere.
local function all_bare(): boolean
    for _, plant in ipairs(plants) do
        if drawn(plant.x, plant.y, plant.look) ~= nil then
            return false
        end
    end
    return true
end
local bare = ignition_room.run_until(900, 5, all_bare)
assert(bare ~= nil, "the fire burnt every plant tile")
assert(#t.ledger_rows("IgnitionAt") >= 1, "the fire is on the record")

for _, plant in ipairs(plants) do
    assert(#t.seen_ground(p, plant.x, plant.y) == 1, "the soil face stays" .. at(plant))
    local ash = drawn(plant.x, plant.y, "powder")
    assert(ash ~= nil and ash.tint == ASH, "ash lies" .. at(plant))
end

-- Nothing left to burn: the tending task drops every latch, the moss
-- last, as its thin remainder smoulders out.
local out = ignition_room.run_until(120, 1, function()
    return ignition_room.count(ignition_room.latched_tiles()) == 0
end)
assert(out ~= nil, "every latch let go once the plants were gone")

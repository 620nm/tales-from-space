local matter_look = require("@helpers/matter_look")

-- An edge only ever marks what the viewer was told.
--
-- A hall with a short run of puddles near the player and a long one that
-- runs out past the limit of sight. The short run ends in a real edge:
-- its neighbor is a dry tile the client was told about. The long run
-- reaches the last tile the client can see and its neighbor is one it
-- was never told about, which reads as joined, so no edge is drawn
-- where the water might simply go on. Past that tile the client knows
-- nothing at all: the spec read returns no parts for it, and none for a
-- closet behind a wall that holds water and gas of its own.

t.set_breathing(false)

local WIDTH = 45
local SHORT_FROM, SHORT_TO = 2, 4

local function painted_run(y: number, from: number, to: number): string
    local tiles = table.create(to - from + 1)
    for x = from, to do
        table.insert(tiles, string.format('(%d, %d, "film")', x, y))
    end
    return table.concat(tiles, ", ")
end

local hall = "#" .. string.rep(".", WIDTH - 2) .. "#"
local wall = string.rep("#", WIDTH)
local closet = string.rep("#", 3) .. "." .. string.rep("#", WIDTH - 4)

t.world(
    string.format(
        [==[(
    name: "sight limit",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "%s",
                "%s",
                "%s",
                "%s",
                "%s",
                "%s",
                "%s",
            ],
            structures: [(1, 2, "player_spawn")],
            painted: [%s, %s, (3, 5, "film")],
        ),
    ],
    blends: {
        "film": (rows: [("water", 55.51), ("chlorine", 30.0), ("o2", 26.19), ("n2", 98.53)], temperature_k: 293.15, amount: total),
    },
)]==],
        wall,
        hall,
        hall,
        hall,
        wall,
        closet,
        wall,
        painted_run(1, SHORT_FROM, SHORT_TO),
        painted_run(3, SHORT_FROM, WIDTH - 2)
    ),
    0
)

local p = t.join()
t.tick()

-- The last tile of the long run the client was told about.
local last = 0
for x = SHORT_FROM, WIDTH - 2 do
    if #t.seen_composition(p, x, 3) == 0 then
        break
    end
    last = x
end
assert(last > SHORT_TO + 2, "the hall shows more than a few tiles: " .. last)
assert(last < WIDTH - 2, "and not all of it: the long run must leave sight")

-- A real edge: the dry tile past the short run was told about.
local short_end = assert(matter_look.find(p, SHORT_TO, 1, "puddle", 4), "the short run draws the shell")
local short_joins = matter_look.edges(short_end)
assert(not short_joins.e, "a dry tile in sight is an edge")
assert(short_joins.w, "and the run behind it is joined")

-- No false edge: the neighbor past the limit of sight reads as joined.
local limit = assert(matter_look.find(p, last, 3, "puddle", 4), "the last visible tile draws the shell")
local limit_joins = matter_look.edges(limit)
assert(limit_joins.e, "an untold neighbor reads as joined, so no edge is drawn at the limit of sight")
assert(limit_joins.w, "and the run behind it is joined")
assert(not limit_joins.n, "while a dry tile in sight is still an edge")

-- Security: tiles the client was not told return no parts.
assert(#t.seen_composition(p, last + 1, 3) == 0, "the tile past the limit is not shown")
assert(#t.seen_matter(p, last + 1, 3) == 0, "and its water and gas are not read")
assert(#t.seen_matter(p, WIDTH - 2, 3) == 0, "nor are those at the far end of the run")
assert(#t.seen_composition(p, 3, 5) == 0, "the closet behind the wall is not shown")
assert(#t.seen_matter(p, 3, 5) == 0, "and the water and gas inside it are not read")

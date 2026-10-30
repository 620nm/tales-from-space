-- One machine on nine tiles, asked about the way a player would ask.
--
-- The gravity battery is this pack's widest footprinted entry, so this
-- file is where "a body standing on several tiles" is proved: what a
-- corner answers, which cells you walk into, that a tool on a corner
-- works the machine rather than the tile, and which cell wears the
-- running disc. The walk-under cell mechanism is the engine's fixture
-- test (no pack entry has a walk-under cell).
--
-- The battery is anchored on its centre tile, so one at (5, 5) stands on
-- (4..6, 4..6); its south emitter cell is (5, 6).
local bench = require("@helpers/grav_bench")

local function line(look, want)
    for _, l in ipairs(look.lines) do
        if l == want then
            return true
        end
    end
    return false
end

local ROOM = [==[(
    name: "battery bay",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "###########",
                "#.........#",
                "#.........#",
                "#.........#",
                "#.........#",
                "#.........#",
                "#.........#",
                "#.........#",
                "#.........#",
                "#.........#",
                "###########",
            ],
            items: [(7, 4, "screwdriver")],
            structures: [(5, 8, "player_spawn"), (5, 5, "grav_smes", "standby")],
        ),
    ],
)]==]

t.world(ROOM, 7)
local p = t.join()
t.tick()

-- ---------------------------------------------------------------
-- Every cell answers as the BODY.
-- ---------------------------------------------------------------
for dy = -1, 1 do
    for dx = -1, 1 do
        local x, y = 5 + dx, 5 + dy
        local it = t.structure_at(x, y)
        assert(
            it and it.id == "grav_smes",
            "(" .. x .. ", " .. y .. ") is the battery, got " .. tostring(it and it.id)
        )
        assert(
            string.find(it.state or "", "^standby") ~= nil,
            "and it stands finished, got " .. tostring(it.state)
        )
    end
end
assert(t.structure_at(3, 5) == nil, "the tile beside it is bare floor")
assert(t.structure_at(5, 3) == nil, "and so is the tile above its top row")

-- ---------------------------------------------------------------
-- Nine cells you walk into.
-- ---------------------------------------------------------------
local function step(dir)
    t.move(p, dir)
    t.run_ticks(4)
    local x, y = t.pos(p)
    return x, y
end

local function walk(dir, wx: number, wy: number, why: string)
    local x, y = step(dir)
    assert(
        x == wx and y == wy,
        why .. ": expected (" .. wx .. ", " .. wy .. "), got (" .. x .. ", " .. y .. ")"
    )
end

local function blocked(dir, wx: number, wy: number, cell: string)
    local x, y = step(dir)
    assert(
        x == wx and y == wy,
        "cell "
            .. cell
            .. " is solid: expected to stay at ("
            .. wx
            .. ", "
            .. wy
            .. "), got ("
            .. x
            .. ", "
            .. y
            .. ")"
    )
end

walk("north", 5, 7, "the floor below the battery is floor")
blocked("north", 5, 7, "the south emitter")
walk("west", 4, 7, "west along the bottom")
blocked("north", 4, 7, "the south-west ring")
walk("west", 3, 7, "clear of the block")
walk("north", 3, 6, "up the free column")
walk("north", 3, 5, "still climbing")
blocked("east", 3, 5, "the west emitter")
walk("north", 3, 4, "level with the top row")
blocked("east", 3, 4, "the north-west ring")
walk("north", 3, 3, "above the block")
walk("east", 4, 3, "along the top")
walk("east", 5, 3, "above the north emitter")
blocked("south", 5, 3, "the north emitter, a top row nobody walks under")

-- ---------------------------------------------------------------
-- Every cell says whose it is, and draws its own part of the picture.
-- ---------------------------------------------------------------
local body = t.target_at(p, 5, 5, "grav_smes")
local corner = t.target_at(p, 6, 4, "grav_smes")
assert(
    body and corner and body ~= corner,
    "a corner has a wire id of its own, distinct from the body's"
)

local top = t.seen(p, corner)
assert(top.kind == "machine", "a corner keeps machine identity, got " .. tostring(top.kind))
assert(
    t.same_target(assert(top.extent_of), body),
    "and names the body it belongs to, got " .. tostring(top.extent_of)
)
assert(
    top.layers[1] and top.layers[1].sprite == "grav_smes_standby_0_2",
    "wearing its own part's picture, got " .. tostring(top.layers[1] and top.layers[1].sprite)
)

-- ---------------------------------------------------------------
-- Looking at a corner names the machine, not the tile.
-- ---------------------------------------------------------------
local look = t.examine(p, 6, 4, corner)
assert(
    look and look.title == "gravity battery",
    "a look at the corner names the machine, got " .. tostring(look and look.title)
)
assert(
    look.sprite == "grav_smes_standby_1_1",
    "and shows the body's own picture, got " .. tostring(look.sprite)
)
assert(
    line(look, "Four emitters and four supermagnet rings, welded around a core."),
    "with the body's flavor: " .. table.concat(look.lines, " | ")
)

-- ---------------------------------------------------------------
-- A RUNNING battery: the same nine cells, and the disc on the centre
-- cell's stack alone.
-- ---------------------------------------------------------------
t.world(ROOM:gsub('"standby"', '"active"'), 7)
local q = t.join()
t.run_ticks(4)

local centre = t.seen(q, t.target_at(q, 5, 5, "grav_smes"))
assert(#centre.layers == 2, "the centre wears two layers, got " .. #centre.layers)
assert(
    centre.layers[2].sprite == "grav_disc_active",
    "the disc over its own part, got " .. tostring(centre.layers[2].sprite)
)
local edge = t.seen(q, t.target_at(q, 4, 5, "grav_smes"))
assert(#edge.layers == 1, "and no other cell wears it, got " .. #edge.layers)

-- ---------------------------------------------------------------
-- A tool on a corner works the machine. Reach is measured to the tile
-- CLICKED, so standing beside a corner is enough to work a machine
-- whose own tile is two steps away.
-- ---------------------------------------------------------------
t.world(ROOM:gsub('"standby"', '"clamped"'):gsub("%(5, 8, ", "(7, 4, "), 7)
local r = t.join()
t.run_ticks(4)
bench.hold(r, "screwdriver", { { 7, 4 } })
t.messages(r)
t.click(r, 6, 4, t.target_at(r, 6, 4, "grav_smes"))
t.run_seconds(4.5)
local after = t.structure_at(5, 5)
assert(
    after and after.state == "welded",
    "the screwdriver on a corner unscrews the clamps, got " .. tostring(after and after.state)
)
assert(
    bench.told(r, "The yoke clamps come off."),
    "and says so: " .. table.concat(t.messages(r), " | ")
)
assert(t.ledger_has("StructureStep", "grav_smes", "welded"), "the round ledger carries the step")

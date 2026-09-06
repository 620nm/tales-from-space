-- One machine on nine tiles, asked about the way a player would ask.
--
-- The gravitational generator is this pack's only footprinted entry, so
-- this file is where "a body standing on several tiles" is proved: what
-- a corner answers, which cells you walk into and which you walk under,
-- and that a tool on a corner works the machine rather than the tile.
--
-- The block is laid from the BOTTOM-MIDDLE tile, tg's part 8
-- (gravitygenerator.dm:179-198), so a generator anchored at (5, 6)
-- stands on (4..6, 4..6) and its walk-under head is the row at y = 4.

local function has(list, want)
    for _, v in ipairs(list) do
        if v == want then
            return true
        end
    end
    return false
end

local function line(look, want)
    for _, l in ipairs(look.lines) do
        if l == want then
            return true
        end
    end
    return false
end

local ROOM = [==[(
    name: "generator bay",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
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
    spawns: [(5, 8)],
    items: [
        (7, 4, "screwdriver"), (7, 4, "welder"),
        (7, 4, "plasteel"), (7, 4, "wrench"),
    ],
    structures: [(5, 6, "gravity_generator", "fix0")],
)]==]

t.world(ROOM, 7)
local p = t.join()
t.tick()

-- ---------------------------------------------------------------
-- Every cell answers as the BODY.
-- ---------------------------------------------------------------
for _, at in ipairs({ { 5, 6 }, { 4, 4 }, { 6, 4 }, { 4, 6 }, { 6, 6 }, { 5, 5 } }) do
    local it = t.structure_at(at[1], at[2])
    assert(it and it.id == "gravity_generator",
        "(" .. at[1] .. ", " .. at[2] .. ") is the generator, got "
            .. tostring(it and it.id))
    assert(it.state == "fix0", "and it is broken at the first rung, got "
        .. tostring(it.state))
end
assert(t.structure_at(3, 6) == nil, "the tile beside it is bare floor")
assert(t.structure_at(5, 3) == nil, "and so is the tile above its head")

-- ---------------------------------------------------------------
-- Six cells you walk into, three you walk under.
-- ---------------------------------------------------------------
local function step(dir)
    t.move(p, dir)
    t.run_ticks(4)
    local x, y = t.pos(p)
    return x, y
end

local function walk(dir, wx, wy, why)
    local x, y = step(dir)
    assert(x == wx and y == wy,
        why .. ": expected (" .. wx .. ", " .. wy .. "), got (" .. x .. ", " .. y .. ")")
end

local function blocked(dir, wx, wy, cell)
    local x, y = step(dir)
    assert(x == wx and y == wy,
        "cell " .. cell .. " is solid: expected to stay at (" .. wx .. ", " .. wy
            .. "), got (" .. x .. ", " .. y .. ")")
end

walk("north", 5, 7, "the floor below the generator is floor")
blocked("north", 5, 7, "8 (the anchor)")
walk("west", 4, 7, "west along the bottom")
blocked("north", 4, 7, "9")
walk("west", 3, 7, "clear of the block")
walk("north", 3, 6, "up the free column")
walk("north", 3, 5, "still climbing")
blocked("east", 3, 5, "6")
walk("north", 3, 4, "level with the head")
walk("east", 4, 4, "the head is walk-under")
walk("east", 5, 4, "and you can cross the whole of it")
blocked("south", 5, 4, "5 (the centre)")
walk("east", 6, 4, "out the far side of the head")
walk("east", 7, 4, "and off it")
walk("south", 7, 5, "down the east flank")
blocked("west", 7, 5, "4")
walk("south", 7, 6, "further down")
walk("south", 7, 7, "to the bottom row")
walk("west", 6, 7, "under the corner")
blocked("north", 6, 7, "7")

-- Back to the head, which is where the tools are.
walk("east", 7, 7, "back out east")
walk("north", 7, 6, "north")
walk("north", 7, 5, "north")
walk("north", 7, 4, "and up beside the far corner of the head")

-- ---------------------------------------------------------------
-- The head is drawn OVER whatever stands on it, and every cell says
-- whose it is.
-- ---------------------------------------------------------------
local body = t.target_at(5, 6, "gravity_generator")
local cell1 = t.target_at(6, 4, "gravity_generator")
assert(body and cell1 and body ~= cell1,
    "a corner has a wire id of its own, distinct from the body's")

local head = t.seen(p, cell1)
assert(head.kind == "overhead",
    "the head draws over what stands on it, got " .. tostring(head.kind))
assert(head.extent_of == body,
    "and names the body it belongs to, got " .. tostring(head.extent_of))
assert(head.layers[1] and head.layers[1].sprite == "gravgen_fix0_1",
    "wearing its own part's picture, got "
        .. tostring(head.layers[1] and head.layers[1].sprite))

local flank = t.seen(p, t.target_at(6, 5, "gravity_generator"))
assert(flank.kind ~= "overhead", "the solid rows are not overhead")
assert(flank.extent_of == body, "but belong to the same body")

-- ---------------------------------------------------------------
-- Looking at a corner names the machine, not the tile.
-- ---------------------------------------------------------------
local look = t.examine(p, 6, 4, cell1)
assert(look and look.title == "gravitational generator",
    "a look at the corner names the machine, got "
        .. tostring(look and look.title))
assert(look.sprite == "gravgen_fix0_8",
    "and shows the body's own picture, got " .. tostring(look.sprite))
assert(line(look, "A device which produces a graviton field when set up."),
    "with the body's flavor: " .. table.concat(look.lines, " | "))

-- ---------------------------------------------------------------
-- The repair ladder, worked from the far corner of the head. Reach is
-- measured to the tile CLICKED, so standing beside a corner is enough
-- to work a machine whose own tile is two steps away.
-- ---------------------------------------------------------------
local function grab(id)
    t.drop(p)
    t.run_ticks(2)
    t.click(p, 7, 4, t.target_at(7, 4, id))
    t.run_ticks(2)
    assert(has(t.hands(p), id), "picked up the " .. id)
    t.messages(p)
end

local function rung(tool, to, said)
    grab(tool)
    t.click(p, 6, 4, t.target_at(6, 4, "gravity_generator"))
    t.run_seconds(1.0)
    local it = t.structure_at(5, 6)
    assert(it and it.state == to,
        "the " .. tool .. " takes it to " .. to .. ", got "
            .. tostring(it and it.state))
    assert(has(t.messages(p), said), "and says so: " .. said)
    assert(t.ledger_has("StructureStep", "gravity_generator", to),
        "the shift ledger carries the rung to " .. to)
    assert(t.seen(p, cell1).layers[1].sprite == "gravgen_" .. to .. "_1",
        "and the corner re-derives its own picture for " .. to .. ", got "
            .. tostring(t.seen(p, cell1).layers[1].sprite))
end

rung("screwdriver", "fix1", "You secure the screws of the framework.")
rung("welder", "fix2", "You mend the damaged framework.")

-- A wrench on the rung that wants plasteel is not a rung at all, and
-- the right shape of "no" is silence: tg's `wrench_act` returns NONE
-- unless `broken_state` is already GRAV_NEEDS_WRENCH
-- (gravitygenerator.dm:264-266), so the tool simply finds nothing to
-- say.
grab("wrench")
t.click(p, 6, 4, t.target_at(6, 4, "gravity_generator"))
t.run_seconds(1.0)
assert(t.structure_at(5, 6).state == "fix2",
    "the wrong tool leaves the ladder where it was")
assert(#t.messages(p) == 0,
    "and says nothing: " .. table.concat(t.messages(p), " | "))

rung("plasteel", "fix3", "You add the plating to the framework.")
rung("wrench", "off", "You secure the plating to the framework.")

assert(t.structure_at(5, 6).sprite == "gravgen_off_8",
    "a mended generator comes back shut down, got "
        .. tostring(t.structure_at(5, 6).sprite))

-- ---------------------------------------------------------------
-- A RUNNING generator: the same nine cells, and the charge overlay on
-- the middle part alone (`center_part.add_overlay("activated")`,
-- gravitygenerator.dm:167).
-- ---------------------------------------------------------------
t.world(ROOM:gsub('"fix0"', '"on"'), 7)
local q = t.join()
t.run_ticks(4)

assert(t.structure_at(5, 6).sprite == "gravgen_on_8", "it is running")
local centre = t.seen(q, t.target_at(5, 5, "gravity_generator"))
assert(#centre.layers == 2, "the centre wears two layers, got " .. #centre.layers)
assert(centre.layers[1].sprite == "gravgen_on_5"
    and centre.layers[2].sprite == "gravgen_activated",
    "its own part under the charge overlay, got "
        .. centre.layers[1].sprite .. " + " .. tostring(centre.layers[2].sprite))

local off_centre = t.seen(q, t.target_at(4, 5, "gravity_generator"))
assert(#off_centre.layers == 1,
    "and no other cell wears it, got " .. #off_centre.layers)

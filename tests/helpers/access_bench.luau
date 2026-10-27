-- Shared bench for the access specs: one powered corridor on row 1, columns
-- 1..14, with a generator and an APC at its west end. Leaves sit in that row;
-- a spec places its spawns, leaves and items as RON tuple text, and the bench
-- supplies the grid, the walls and the map text.
local clock = require("@helpers/clock")

local access_bench = {}

local WIDTH = 16 -- columns 0..15; column 15 is the east wall
local FLOOR_END = WIDTH - 2 -- the last walkable column of row 1

local LEGEND = [==[
        legend: {
            '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
            '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
            'G': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
            'A': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
            'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        },
]==]

local ROWS = "        rows: [\n"
    .. '            "' .. string.rep("#", WIDTH) .. '",\n'
    .. '            "#' .. string.rep(".", FLOOR_END) .. '#",\n'
    .. '            "#GA.o' .. string.rep("#", WIDTH - 5) .. '",\n'
    .. '            "' .. string.rep("#", WIDTH) .. '",\n'
    .. "        ],\n"

local function cable(x: number, y: number, channel: string): string
    return "(x: " .. x .. ", y: " .. y .. ", network: \"power\", channel: \""
        .. channel .. "\", kind: \"cable\", facing: 15),"
end

local cables = {
    cable(1, 2, "l2"),
    cable(2, 2, "l1"),
    cable(2, 2, "l2"),
    cable(3, 2, "l1"),
    cable(4, 2, "l1"),
}
for x = 2, FLOOR_END do
    table.insert(cables, cable(x, 1, "l1"))
end
local NETWORKS = "        networks: [\n            "
    .. table.concat(cables, "\n            ")
    .. "\n        ],\n"

-- The whole map text. `structures` and `items` are RON tuples, comma separated.
function access_bench.source(name: string, structures: string, items: string): string
    return "(\n    name: \"" .. name .. "\",\n"
        .. LEGEND
        .. "    levels: [(\n"
        .. ROWS
        .. "        structures: [(2, 2, \"apc\"), " .. structures .. "],\n"
        .. "        items: [" .. items .. "],\n"
        .. NETWORKS
        .. "    )],\n)"
end

-- Loads a fresh bench with the given tuples.
function access_bench.world(name: string, structures: string, items: string)
    t.world(access_bench.source(name, structures, items), 0)
end

-- A player spawn for `job` on row 1 at column `x`.
function access_bench.spawn(job: string, x: number): string
    return "(" .. x .. ", 1, \"player_spawn\", { \"jobs\": \"" .. job .. "\" })"
end

-- A leaf on row 1 at column `x` with the given RON tuple tail, e.g.
-- `airlock`, `{ "access": "station.medical" }`.
function access_bench.leaf(x: number, id: string, options: string?): string
    local tail = if options == nil then "" else ", " .. options
    return "(" .. x .. ", 1, \"" .. id .. "\"" .. tail .. ")"
end

-- Walks `p` to the tile beside the row-1 door at column `door_x`, bumps it,
-- and gives the leaf its swing. Each step is a real move.
function access_bench.bump(p: number, door_x: number)
    local x = t.pos(p)
    local dir: "east" | "west" = if x < door_x then "east" else "west"
    local stand = if x < door_x then door_x - 1 else door_x + 1
    local steps = 0
    while x ~= stand do
        steps += 1
        assert(steps <= 12, "the walk to the door stalls at column " .. x)
        t.move(p, dir)
        t.run_ticks(5) -- a step is rate-limited; give the cooldown room
        x = t.pos(p)
    end
    t.move(p, dir)
    t.run_ticks(clock.deadline_ticks(0.6) + 3) -- the 0.6 s leaf swing
    -- TfS admits a stale body, so an admission proves nothing unless the derive held.
    assert(#t.ledger_rows("held_set_stale") == 0, "no body's access went stale")
end

-- After a successful `bump` from the west, walks `p` through the open leaf at
-- `door_x` to the tile beyond it, ready to bump the next leaf east.
function access_bench.pass_through(p: number, door_x: number)
    local x = t.pos(p)
    assert(x == door_x - 1, "the walk through starts beside column " .. door_x .. ", not " .. x)
    local steps = 0
    while x ~= door_x + 1 do
        steps += 1
        assert(steps <= 4, "the walk through column " .. door_x .. " stalls at " .. x)
        t.move(p, "east")
        t.run_ticks(5)
        x = t.pos(p)
    end
end

-- Runs until the row-1 leaf at column `door_x` has autoclosed and rests.
function access_bench.wait_until_shut(door_x: number)
    for _ = 1, clock.deadline_ticks(6.0) do
        local door = assert(t.door_at(door_x, 1), "the leaf at " .. door_x .. " exists")
        if not door.open and not door.moving then
            return
        end
        t.run_ticks(1)
    end
    error("the leaf at column " .. door_x .. " never shut")
end

-- A fresh bench holding `leaf` at column 5 and one `job` at column 3; the
-- job bumps the leaf once. True when the leaf stands open afterwards.
function access_bench.bump_admits(job: string, leaf: string): boolean
    access_bench.world("access bench", access_bench.spawn(job, 3) .. ", " .. leaf, "")
    local p = t.join(job)
    t.run_seconds(1.0)
    access_bench.bump(p, 5)
    return assert(t.door_at(5, 1), "the leaf at column 5 exists").open
end

return access_bench

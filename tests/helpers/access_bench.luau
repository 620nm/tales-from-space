-- Shared bench for the access specs: one powered corridor on row 1, x = 1..8,
-- with a generator and an APC at its west end. A spec passes the spawns, doors
-- and items it needs as RON tuple text; the bench supplies the power grid.
local clock = require("@helpers/clock")

local access_bench = {}

local LEGEND = [==[
        legend: {
            '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
            '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
            'G': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
            'A': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
            'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        },
]==]

local ROWS = [==[
        rows: [
            "##########",
            "#........#",
            "#GA.o#####",
            "##########",
        ],
]==]

local NETWORKS = [==[
        networks: [
            (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
            (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
            (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
            (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
            (x: 4, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
            (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
            (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
            (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
            (x: 5, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
            (x: 6, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
            (x: 7, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
            (x: 8, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        ],
]==]

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

-- A player spawn for `job` on row 1 at column `x`.
function access_bench.spawn(job: string, x: number): string
    return "(" .. x .. ", 1, \"player_spawn\", { \"jobs\": \"" .. job .. "\" })"
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
    t.world(access_bench.source("access bench", access_bench.spawn(job, 3) .. ", " .. leaf, ""), 0)
    local p = t.join(job)
    t.run_seconds(1.0)
    access_bench.bump(p, 5)
    return assert(t.door_at(5, 1), "the leaf at column 5 exists").open
end

return access_bench

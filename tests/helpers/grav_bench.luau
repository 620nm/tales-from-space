-- The gravity battery's test room: eight parts around a centre tile
-- (5, 4) in an 11x9 room, a player, and the hand-juggling the assembly
-- specs share.
local bench = {}

export type Override = {
    state: string?,
    dir: string?,
    absent: boolean?,
    packed: boolean?,
}

type Position = {
    key: string,
    id: string,
    x: number,
    y: number,
    dir: string,
}

-- An emitter faces the centre; a ring's facing names its corner arc.
local POSITIONS: { Position } = {
    { key = "n", id = "grav_emitter", x = 5, y = 3, dir = "south" },
    { key = "e", id = "grav_emitter", x = 6, y = 4, dir = "west" },
    { key = "s", id = "grav_emitter", x = 5, y = 5, dir = "north" },
    { key = "w", id = "grav_emitter", x = 4, y = 4, dir = "east" },
    { key = "nw", id = "grav_supermagnet_ring", x = 4, y = 3, dir = "north" },
    { key = "ne", id = "grav_supermagnet_ring", x = 6, y = 3, dir = "east" },
    { key = "se", id = "grav_supermagnet_ring", x = 6, y = 5, dir = "south" },
    { key = "sw", id = "grav_supermagnet_ring", x = 4, y = 5, dir = "west" },
}

bench.CENTER_X = 5
bench.CENTER_Y = 4

-- Every position, so a spec can name one by its key.
function bench.positions(): { Position }
    return POSITIONS
end

function bench.position(key: string): Position
    for _, spot in ipairs(POSITIONS) do
        if spot.key == key then
            return spot
        end
    end
    error("no position " .. key)
end

-- Map rows for the eight parts, anchored and facing inward, with the
-- overrides of the named positions applied. A `packed` ring stands on its cart.
function bench.part_rows(overrides: { [string]: Override }?): string
    local rows = {}
    for _, spot in ipairs(POSITIONS) do
        local named = if overrides ~= nil then overrides[spot.key] else nil
        local change: Override = named or {}
        if change.packed == true then
            table.insert(rows, string.format('(%d, %d, "grav_supermagnet")', spot.x, spot.y))
        elseif change.absent ~= true then
            table.insert(
                rows,
                string.format(
                    '(%d, %d, "%s", "%s", { "dir": "%s" })',
                    spot.x,
                    spot.y,
                    spot.id,
                    change.state or "anchored",
                    change.dir or spot.dir
                )
            )
        end
    end
    return table.concat(rows, ", ")
end

-- The room: `structures` and `items` are map row lists (comma-joined
-- tuples), the player spawn is among `structures`.
function bench.world(structures: string, items: string)
    t.world(
        [==[(
    name: "gravity bay",
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
                "###########",
            ],
            items: []==] .. items .. [==[],
            structures: []==] .. structures .. [==[],
        ),
    ],
)]==],
        7
    )
end

-- Picks `id` up into the active hand from the first of `near` that has
-- one, putting down whatever was held.
function bench.hold(p: number, id: string, near: { { number } })
    if t.hands(p).held == id then
        return
    end
    if t.hands(p).held ~= nil then
        t.drop(p)
        t.run_ticks(2)
    end
    for _, at in ipairs(near) do
        local target = t.target_at(p, at[1], at[2], id)
        if target ~= nil then
            t.click(p, at[1], at[2], target)
            t.run_ticks(2)
            local held = tostring(t.hands(p).held)
            assert(held == id, "picked up " .. id .. ", holding " .. held)
            return
        end
    end
    error("no " .. id .. " within reach")
end

-- Whether the player was told `line` since the last call.
function bench.told(p: number, line: string): boolean
    local found = false
    for _, message in ipairs(t.messages(p)) do
        if message == line then
            found = true
        end
    end
    return found
end

-- The parts at `keys` still stand as their own prototypes.
function bench.assert_standing(keys: { string })
    for _, key in ipairs(keys) do
        local spot = bench.position(key)
        local found = t.structure_at(spot.x, spot.y)
        local standing = tostring(found and found.id)
        assert(found ~= nil and found.id == spot.id, key .. " still stands: " .. standing)
    end
end

return bench

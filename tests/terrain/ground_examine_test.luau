-- A look at bare natural ground names what the ground is, by the blend's
-- localized name (`name_label`, locale/en.json), and a look at a sea says the
-- water fills the ground rather than lying on it as a puddle (the engine's
-- docs/wiki/examine.md). A deck laid over the ground hides it: its look
-- names no ground.
--
-- Columns 0-3 are sand, 4-7 sea, under the `warm_outdoors` sky; (0, 2) and
-- (1, 2) are plating over the sky's generated soil.
t.world(
    [==[(
    name: "ground examine",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), surface_temperature_k: Exact(293.15)),
    legend: {
        'a': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sand_ground"), components: [])),
        'w': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sea_water"), components: [])),
        'p': (outdoors: true, composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    levels: [
        (
            rows: [
                "aaaawwww",
                "aaaawwww",
                "ppaawwww",
            ],
            structures: [(1, 1, "player_spawn")],
        ),
    ],
)]==],
    0,
    "free_build"
)
t.set_breathing(false)

local p = t.join()
t.run_ticks(4)

local function lines_at(x: number, y: number): { string }
    local seen = t.examine(p, x, y)
    assert(seen ~= nil, ("(%d,%d) answers a look"):format(x, y))
    return seen.lines
end

local function has(lines: { string }, want: string): boolean
    for _, line in lines do
        if line == want then
            return true
        end
    end
    return false
end

local function starts(lines: { string }, prefix: string): boolean
    for _, line in lines do
        if string.sub(line, 1, #prefix) == prefix then
            return true
        end
    end
    return false
end

local shore = lines_at(2, 1)
assert(has(shore, "The ground is sand."), "the shore names its ground: " .. table.concat(shore, " | "))
assert(not starts(shore, "Filling the ground"), "and nothing stands in it: " .. table.concat(shore, " | "))

local sea = lines_at(5, 1)
assert(has(sea, "The ground is open sea."), "the sea names its ground: " .. table.concat(sea, " | "))
assert(starts(sea, "Filling the ground here: "), "the sea fills its bed: " .. table.concat(sea, " | "))
assert(not starts(sea, "A puddle"), "and is not a puddle: " .. table.concat(sea, " | "))

local plated = assert(t.examine(p, 0, 2), "the plating answers a look").lines
assert(not starts(plated, "The ground is"), "plating over ground names no ground: " .. table.concat(plated, " | "))

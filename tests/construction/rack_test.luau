-- A rack seats what is put on it, whatever pixel was clicked, and a map
-- may open a stack short of full. Both are this pack's numbers: the
-- engine owns the seating (`surface_slots`) and the row (`units`).
t.world(
    [==[(
    name: "storeroom",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "#####",
                "#...#",
                "#...#",
                "#####",
            ],
            structures: [(1, 1, "player_spawn"), (2, 2, "rack")],
            items: [
                (1, 1, "cable_coil", { "units": 12 }),
                (1, 1, "crowbar"),
                (1, 1, "screwdriver"),
                (1, 1, "wrench"),
                (2, 2, "rod"),
            ],
        ),
    ],
)]==],
    7
)

local p = t.join()
t.tick()

-- A map's own items are seated like a player's, and hold the first slot.
local stocked = assert(t.item_at(2, 2, "rod")).offset
assert(stocked.x == -8 and stocked.y == 5, "the mapped rods take the top-left slot")

local coil = assert(t.target_at(p, 1, 1, "cable_coil"))
assert(t.stack_count(coil) == 12, "the map opened the coil at twelve: " .. t.stack_count(coil))

local function shelve(id: string)
    t.click(p, 1, 1, assert(t.target_at(p, 1, 1, id)))
    t.run_ticks(2)
    assert(t.hands(p).held == id, id .. " in hand")
    t.click_tile(p, 2, 2)
    t.run_ticks(2)
    assert(t.hands(p).held == nil, id .. " left the hand for the rack")
    return assert(t.item_at(2, 2, id), id .. " stands on the rack").offset
end

local first = shelve("screwdriver")
assert(first.x == 0 and first.y == 5, "the next thing sits beside the rods")
local second = shelve("crowbar")
assert(second.x == 8 and second.y == 5, "and the next beside that, not on it")

t.click(p, 1, 1, assert(t.target_at(p, 1, 1, "cable_coil")))
t.run_ticks(2)
t.click_tile(p, 2, 2)
t.run_ticks(2)
local kept = assert(t.target_at(p, 2, 2, "cable_coil"))
assert(t.stack_count(kept) == 12, "a placement is not a merge, and keeps its count")

-- A wrench is the one thing a rack does not take: it takes the rack apart
-- and the sheet comes back, leaving what was on it on the floor.
t.click(p, 1, 1, assert(t.target_at(p, 1, 1, "wrench")))
t.run_ticks(2)
t.click(p, 2, 2, assert(t.target_at(p, 2, 2, "rack")))
t.run_seconds(1.5)
assert(t.structure_at(2, 2) == nil, "the rack came apart")
assert(t.target_at(p, 2, 2, "metal") ~= nil, "and handed back its sheet")
assert(t.target_at(p, 2, 2, "crowbar") ~= nil, "what stood on it stays on the tile")

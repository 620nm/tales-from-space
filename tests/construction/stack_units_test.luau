-- A STACK KEEPS ITS UNITS ACROSS A SPLIT.
--
-- `Handle.count` is the live unit count of a stack for script handlers
-- (docs/luau-api/handles.md); `t.split_stack` is the spec seam onto the same
-- `Sim::split_stack` and answers the two unit counts the stack state holds
-- afterwards (docs/luau-api/item-split.md). A spec holds no Handle, so
-- this reads the counts through the seam rather than through `.count`.
t.world(
    [==[(
    name: "site",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "######",
                "#....#",
                "#....#",
                "######",
            ],
            structures: [(1, 1, "player_spawn")],
            items: [(2, 1, "metal"), (3, 2, "metal"), (4, 1, "crowbar")],
        ),
    ],
)]==],
    7
)

t.tick()

local MAX = 30 -- the sheet's own stack size (content/items/materials/metal.luau)

local function split_error(x: number, y: number, count: number): string
    local ok, err = pcall(t.split_stack, x, y, count)
    assert(not ok, "the split was refused")
    return tostring(err)
end

local function sheets_at(x: number, y: number): number
    local n = 0
    for _, id in ipairs(t.items_at(x, y)) do
        if id == "metal" then
            n += 1
        end
    end
    return n
end

assert(sheets_at(2, 1) == 1, "one loose stack of sheets")

-- A split carves units off and conserves them.
local remaining, split = t.split_stack(2, 1, 5)
assert(split == 5, "the new stack holds what was asked, got " .. split)
assert(remaining == MAX - 5, "the source keeps the rest, got " .. remaining)
assert(remaining + split == MAX, "no unit was minted or lost")
assert(sheets_at(2, 1) == 2, "two stacks now lie on the tile")
assert(t.ledger_has("ItemSplit"), "the split is a ledger row")

-- Two stacks on one tile: the seam wants a lone stack, so it refuses
-- rather than choosing one.
assert(split_error(2, 1, 1):find("lone stack", 1, true), "an ambiguous tile is refused")

-- Taking all of a stack, or more, moves nothing: the refusal is named and
-- the stack still reads whole afterwards.
assert(split_error(3, 2, MAX):find("whole_stack", 1, true), "all of it is not a split")
assert(split_error(3, 2, MAX + 9):find("whole_stack", 1, true), "more than all of it is not a split")
local kept, carved = t.split_stack(3, 2, 1)
assert(kept == MAX - 1 and carved == 1, "the refused attempts changed nothing")

-- A thing with no unit count has no stack to split.
assert(split_error(4, 1, 1):find("lone stack", 1, true), "a crowbar is not a stack")

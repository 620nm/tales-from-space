-- Spilling: a beaker tipped out onto the deck empties, and what was in
-- it becomes matter standing in that tile — not vapour, and not a
-- second system bolted beside the air.
t.world([==[(
    name: "spill room",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    items: [(1, 1, "beaker_libital")],
)]==], 0)

local p = t.join()
t.tick()

local beaker = t.target_at(1, 1, "beaker_libital")
local function total(handle)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    local n = 0
    for _, moles in pairs(contents) do
        n = n + moles
    end
    return n
end

t.click(p, 1, 1, beaker) -- pick it up
t.tick()
assert(math.abs(total(beaker) - 0.35) < 1e-9, "a full beaker")

-- What the room is breathing before anything is tipped into it.
local before = t.room_gas(2, 1)
local gas_before = 0
for _, moles in pairs(before) do
    gas_before = gas_before + moles
end

t.click(p, 2, 1) -- the deck beside you, with the beaker in hand
t.tick()
assert(math.abs(total(beaker)) < 1e-9, ("the beaker is empty, got %g"):format(total(beaker)))

-- A puddle is a LIQUID in that tile's cell: the room's gas load is
-- exactly what it was, because nothing gasified.
local after = t.room_gas(2, 1)
local gas_after = 0
for _, moles in pairs(after) do
    gas_after = gas_after + moles
end
assert(
    math.abs(gas_after - gas_before) < 1e-6,
    ("the air is unchanged: %g -> %g"):format(gas_before, gas_after)
)

local rows = t.ledger_rows("spilled")
assert(#rows == 1, ("one spill on the record, got %d"):format(#rows))
assert(math.abs(rows[1].moles - 0.35) < 1e-9, "the row names the whole beaker")
assert(rows[1].at[1] == 2 and rows[1].at[2] == 1, "and the tile it landed on")
assert(rows[1].actor.kind == "script", "attributed to the file that asked")

-- An empty beaker has nothing left to tip out: the gesture is refused
-- and writes no second row.
t.click(p, 2, 1)
t.tick()
assert(#t.ledger_rows("spilled") == 1, "the empty beaker spilled nothing")

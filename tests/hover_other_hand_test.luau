-- The hover card of the ACTIVE-hand item names what the use-other-hand key
-- (`use_other`) would do with the item in the other hand: one `other` row
-- whose second line reads "In other hand". Either way round, a floppy and a
-- laptop offer the laptop's `insert_disk` (items/laptop.luau, a receiver row
-- judged with the floppy as `held`).
t.world([==[(
    name: "other hand desk",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    // Both within reach of the spawn: `t.target_at` picks by prototype.
    items: [(2, 1, "laptop"), (2, 1, "floppy_disk")],
)]==], 0)

local p = t.join()
t.tick()

local function take(x, id)
    t.click(p, x, 1, t.target_at(p, x, 1, id))
    t.run_ticks(2)
    assert(t.hands(p).held == id, "picked up " .. id .. "; hands=" .. tostring(t.hands(p).held))
end

-- The `other` rows on a held item's card, by hand role.
local function other_rows(role)
    local hands = t.hands(p)
    local hand = if role == "active" then hands.active - 1 else 2 - hands.active
    local rows = {}
    for _, action in ipairs(t.action_hints(p, { Inventory = { Held = { hand = hand } } })) do
        if action.gesture == "other" then
            table.insert(rows, action)
        end
    end
    return rows
end

local function assert_insert(rows, why)
    assert(#rows == 1, why .. ": one other-hand row, got " .. #rows)
    local row = rows[1]
    assert(row.id == "other/insert_disk", why .. ": id " .. tostring(row.id))
    assert(row.label.key == "lunatic/tfs:ui.affordance.insert_disk", why .. ": label")
    assert(row.available, why .. ": available")
    assert(row.detail and row.detail.key == "engine.action.other_hand", why .. ": detail line")
    assert(row.implement ~= nil, why .. ": the implement is pictured")
end

take(2, "floppy_disk")
assert(#other_rows("active") == 0, "an empty other hand offers no other-hand row")

t.swap_hands(p)
t.run_ticks(2)
take(2, "laptop")
assert_insert(other_rows("active"), "laptop active, floppy other")
assert(#other_rows("other") == 0, "the other-hand item's card shows ordinary rows only")

t.swap_hands(p)
t.run_ticks(2)
assert(t.hands(p).held == "floppy_disk", "the floppy is active again")
assert_insert(other_rows("active"), "floppy active, laptop other")

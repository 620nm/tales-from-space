-- The hover card's `other` row and the use-other-hand key agree: where the
-- active item's card offers `other/insert_disk`, the key inserts the disk;
-- where it offers no `other` row, the key reports a dead end. A floppy and a
-- laptop pair either way round (items/laptop.luau's `insert_disk` receiver
-- row, judged with the floppy as `held`); a crowbar has nothing to do with a
-- laptop in either direction.
t.world([==[(
    name: "other hand agreement",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    structures: [(1, 1, "player_spawn")],
    // All within reach of the spawn: `t.target_at` picks by prototype.
    items: [(2, 1, "laptop"), (2, 1, "floppy_disk"), (2, 1, "crowbar")],
)]==], 0)

local p = t.join()
t.tick()

local function step() t.run_ticks(2) end

local function take(id)
    t.click(p, 2, 1, (assert(t.target_at(p, 2, 1, id), id .. " is visible")))
    step()
    assert(t.hands(p).held == id, "picked up " .. id .. "; hands=" .. tostring(t.hands(p).held))
end

-- The `other` rows on the active item's card.
local function other_rows()
    local hand = t.hands(p).active - 1
    local rows = {}
    for _, action in ipairs(t.action_hints(p, { Inventory = { Held = { hand = hand } } })) do
        if action.gesture == "other" then
            table.insert(rows, action)
        end
    end
    return rows
end

local function assert_insert_row(why)
    local rows = other_rows()
    assert(#rows == 1, why .. ": one other-hand row, got " .. #rows)
    assert(rows[1].id == "other/insert_disk", why .. ": id " .. tostring(rows[1].id))
    assert(rows[1].available, why .. ": available")
end

local function media_count(kind)
    local count = 0
    for _, row in ipairs(t.ledger_rows()) do
        if row.audit and row.audit.audit == kind then count += 1 end
    end
    return count
end

-- Fire the key; return whether it reported a dead end.
local function use_other()
    t.messages(p)
    t.use_on_other(p)
    step()
    for _, line in ipairs(t.messages(p)) do
        if line:find("can't use those two together", 1, true) then
            return true
        end
    end
    return false
end

-- ---- floppy active, laptop other: the forward pair ------------------------
take("laptop")
local laptop_hand = t.hands(p).active - 1
local held_laptop = { Held = { hand = laptop_hand } }
t.swap_hands(p)
step()
take("floppy_disk")
assert_insert_row("floppy active, laptop other")
local inserted = media_count("media_inserted")
assert(not use_other(), "floppy active: the key is not a dead end")
assert(t.hands(p).held == nil and t.hands(p)[laptop_hand + 1] == "laptop",
    "floppy active: the key inserted the disk the row named")
assert(media_count("media_inserted") == inserted + 1, "forward insertion is recorded")

t.use_item_site(p, held_laptop, "shift_ctrl_primary")
step()
assert(t.hands(p).held == "floppy_disk", "the disk ejects back to the active hand")
local disk_hand = t.hands(p).active - 1

-- ---- laptop active, floppy other: the reverse pair ------------------------
t.swap_hands(p)
step()
assert(t.hands(p).held == "laptop" and t.hands(p)[disk_hand + 1] == "floppy_disk",
    "laptop active, disk in the other hand")
assert_insert_row("laptop active, floppy other")
assert(not use_other(), "laptop active: the key is not a dead end")
assert(t.hands(p).held == "laptop" and t.hands(p)[disk_hand + 1] == nil,
    "laptop active: the key inserted the other hand's disk")
assert(media_count("media_inserted") == inserted + 2, "reverse insertion is recorded")

-- ---- laptop and a crowbar: no combination --------------------------------
t.swap_hands(p)
step()
take("crowbar")
t.swap_hands(p)
step()
assert(t.hands(p).held == "laptop", "laptop active, crowbar in the other hand")
assert(#other_rows() == 0, "laptop active, crowbar other: no other-hand row")
assert(use_other(), "laptop active, crowbar other: the key reports a dead end")
assert(t.hands(p).held == "laptop" and t.hands(p)[disk_hand + 1] == "crowbar", "nothing moved")

t.swap_hands(p)
step()
assert(t.hands(p).held == "crowbar", "crowbar active, laptop in the other hand")
assert(#other_rows() == 0, "crowbar active, laptop other: no other-hand row")
assert(use_other(), "crowbar active, laptop other: the key reports a dead end")
assert(t.hands(p).held == "crowbar" and t.hands(p)[laptop_hand + 1] == "laptop", "nothing moved")

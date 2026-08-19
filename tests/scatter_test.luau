-- Things do not sit dead centre on their tile.
--
-- A station whose every object is stamped on the middle of its square
-- reads as a spreadsheet. tg's fix is one pair of numbers per atom
-- (`pixel_x`/`pixel_y`) jittered at the moments a thing ARRIVES
-- somewhere, and this asserts all three moments plus the two rules
-- that travel with them.
--
-- The user-visible case, and the one this file exists for: crowbar a
-- floor tile and the tile that comes up is crooked. tg does that in
-- the tile stack's own `Initialize` rather than in the prying code
-- (code/game/objects/items/stacks/tiles/tile_types.dm:35-36), which is
-- why a tile a mapper placed is crooked in exactly the same way.
--
-- NOT seed-pinned to particular numbers. The interesting claim is a
-- RELATION -- the offset is inside the declared spread, it is not
-- always zero, and two things do not share one -- and pinning an exact
-- jitter would break on any change to how many numbers the engine
-- draws, which is a thing that has already happened once (dice_test).
t.world([==[(
    name: "workshop",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '_': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#......#",
        "#______#",
        "########",
    ],
    spawns: [(1, 2)],
    items: [(1, 2, "crowbar"), (4, 2, "d6"), (5, 2, "d20")],
)]==], 0)

local p = t.join()
t.tick()

-- ---- a mapper's tile and a pried-up one are crooked alike -----------
-- Nothing has touched these; they are jittered because the PROTOTYPE
-- asks to be, the moment it exists.
local SPREAD = 3
local function within(off, spread, what)
    assert(off ~= nil, what .. " has an offset at all")
    assert(math.abs(off.x) <= spread and math.abs(off.y) <= spread,
        what .. " is inside its declared spread: " .. off.x .. "," .. off.y)
end

t.click(p, 1, 2, t.target_at(1, 2, "crowbar"))
t.tick()
assert(t.hands(p).held == "crowbar", "the crowbar is in hand")

-- Pry four tiles up and look at what lands. Four rather than one
-- because a single tile could be centred by luck: 3 of 49 offsets are,
-- so one tile proves nothing and four make it a 1-in-2900 fluke.
local crooked, seen = 0, {}
for x = 1, 4 do
    -- Walk along the plating and pry the floor tile beside you. Reach
    -- is one tile, so a spec must stand where a player would have to.
    if x > 1 then
        t.move(p, "east")
        t.run_ticks(5)
    end
    local px = t.pos(p)
    assert(px == x, "standing under the tile being pried: " .. px .. " vs " .. x)
    t.click(p, x, 1)
    t.run_ticks(4)
    local tile = t.item_at(x, 1, "floor_tile")
    assert(tile ~= nil, "a tile came up at " .. x .. ",1")
    within(tile.offset, SPREAD, "the pried tile at " .. x .. ",1")
    if tile.offset.x ~= 0 or tile.offset.y ~= 0 then
        crooked += 1
    end
    seen[#seen + 1] = tile.offset.x .. "," .. tile.offset.y
end
assert(crooked > 0,
    "a pried-up tile lands crooked rather than square: " .. table.concat(seen, " "))

-- ...and they are not all crooked the SAME way, which is what tells a
-- per-instance jitter from a constant baked into the prototype.
local distinct = {}
for _, o in ipairs(seen) do
    distinct[o] = true
end
local kinds = 0
for _ in pairs(distinct) do
    kinds += 1
end
assert(kinds > 1, "each tile got its own offset, not one shared: " .. table.concat(seen, " "))

-- ---- dropped out of a hand ------------------------------------------
-- Wider than a tile's own jitter: tg drops at +/-6
-- (code/modules/mob/inventory.dm:356-357). The prying walk ended at
-- (4, 2), which is where the dice were left for it.
t.drop(p)
t.tick()
t.click(p, 4, 2, t.target_at(4, 2, "d6"))
t.tick()
assert(t.hands(p).held == "d6", "the die is in hand")
t.drop(p)
t.tick()
local dropped = t.item_at(4, 2, "d6")
assert(dropped ~= nil, "the die is at the dropper's feet")
within(dropped.offset, 6, "a dropped die")

-- Dropping it AGAIN recomputes from the prototype's anchor rather than
-- adding to what was there. tg overwrites for exactly this reason
-- (`transfer_item_to_turf`, inventory.dm:378-379): an item that
-- accumulated would walk itself off its own tile.
local wandered = false
for _ = 1, 12 do
    t.click(p, 4, 2, t.target_at(4, 2, "d6"))
    t.tick()
    t.drop(p)
    t.tick()
    local again = t.item_at(4, 2, "d6")
    within(again.offset, 6, "a die dropped over and over")
    wandered = wandered or math.abs(again.offset.x) > 6 or math.abs(again.offset.y) > 6
end
assert(not wandered, "twelve drops never walk it past one drop's reach")

-- ---- landed from a throw --------------------------------------------
-- Wider again: tg throws at +/-8 (code/game/objects/items.dm:899-900).
-- A die thrown out of a hand starts centred, which is also the
-- condition tg guards the roll on.
t.click(p, 5, 2, t.target_at(5, 2, "d20"))
t.tick()
assert(t.hands(p).held == "d20", "the good one is in hand")
t.throw(p, 6, 2)
t.run_ticks(10)
local landed = t.item_at(6, 2, "d20")
assert(landed ~= nil, "it flew and stopped")
within(landed.offset, 8, "a thrown die")

-- ---- and it is still on its tile -------------------------------------
-- The whole mechanism is cosmetic. A crooked thing is still ON its
-- tile: it is picked up by clicking that tile, and every server-side
-- answer is computed from the tile rather than from the picture.
assert(landed.offset.x ~= 0 or landed.offset.y ~= 0,
    "the thrown die really is off centre: " .. landed.offset.x .. "," .. landed.offset.y)
t.move(p, "east")
t.run_ticks(5)
t.move(p, "east")
t.run_ticks(5)
t.click(p, 6, 2, t.target_at(6, 2, "d20"))
t.tick()
assert(t.hands(p).held == "d20", "a crooked thing is picked up off its own tile")

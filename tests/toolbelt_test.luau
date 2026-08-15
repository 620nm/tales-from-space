-- An engineer signs on wearing a stocked toolbelt AND a backpack. The
-- mob gets only tg's directional worn-belt art: the one-direction
-- content overlays belong to the ordinary belt object, not its worn
-- appearance. Inventory rows still track every stored tool.
t.world([==[(
    name: "locker room",
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
    spawns: [(1, 1), (2, 1)],
)]==], 7)

local eng = t.join("engineer")
t.tick()

-- Both containers at once, which is the point: tg's engineer wears a
-- belt AND a backpack, and one slot could never hold both.
local worn = t.worn(eng)
assert(worn.belt == "toolbelt", "the belt is on the waist, got " .. tostring(worn.belt))
assert(worn.back == "backpack", "the backpack is still on the back")
assert(worn.uniform == "uniform_eng", "and the jumpsuit is still on")
assert(worn.id == "id_engineering", "and the ID is still clipped on")

-- Stocked from the belt's own roster, in order (tg belt.dm:119).
local belt = t.stored(eng, "belt")
assert(#belt == 7, "seven tools on the belt, got " .. #belt)
assert(table.concat(belt, ",")
    == "screwdriver,wrench,welder,crowbar,wirecutters,multitool,cable_coil",
    "the engineering tool suite, in order: " .. table.concat(belt, ","))

-- The bulky stock rides the pack instead, and the headset with it.
local pack = t.stored(eng, "back")
assert(table.concat(pack, ",") == "metal,floor_tile,headset",
    "the pack keeps what a belt cannot: " .. table.concat(pack, ","))

local function drawn(name)
    for _, layer in ipairs(t.layers(eng)) do
        if layer == name then
            return true
        end
    end
    return false
end

-- The worn sprite already depicts the utility belt. None of tg's
-- one-direction obj/clothing/belt_overlays art may be pasted over the
-- directional mob sprite.
assert(drawn("worn_toolbelt"), "the worn belt reached the wire")
for _, sprite in ipairs({
    "belt_wrench", "belt_screwdriver", "belt_crowbar",
    "belt_cutters", "belt_multitool",
}) do
    assert(not drawn(sprite), sprite .. " is object art, not worn art")
end

-- Pull the wrench (row 2) into a hand: the inventory changes while the
-- correct worn sprite remains stable.
t.take_from(eng, "belt", 2)
t.tick()
assert(t.hands(eng).held == "wrench", "the wrench is in hand")
assert(#t.stored(eng, "belt") == 6, "and off the belt")
assert(drawn("worn_toolbelt"), "and the belt itself did not vanish")

-- Put it back: the inventory row answers again without adding object
-- overlays to the mob.
t.store(eng, "belt")
t.tick()
assert(t.hands(eng).held == nil, "the hand is empty again")
assert(#t.stored(eng, "belt") == 7, "seven back on the belt")
assert(not drawn("belt_wrench"), "object art still stays off the mob")

-- NEGATIVE: a belt row is not a backpack row. Taking index 1 from the
-- BACK slot must hand over the pack's first item, never the belt's —
-- a TakeFrom that ignored its slot would silently loot the wrong bag.
t.take_from(eng, "back", 1)
t.tick()
assert(t.hands(eng).held == "metal", "the back slot answers for the back slot")
assert(#t.stored(eng, "belt") == 7, "the belt was not touched")

-- NEGATIVE: a row that does not exist changes nothing (a stale click
-- from a client whose panel is a tick behind).
t.swap_hands(eng)
t.take_from(eng, "belt", 99)
t.tick()
assert(t.hands(eng).held == nil, "no such row, nothing taken")
assert(#t.stored(eng, "belt") == 7, "and nothing left the belt")

-- NEGATIVE: another crewman is told what the engineer WEARS (that is
-- public, as in tg), while its private rows are not represented by
-- object overlays on either viewer's mob composition.
local mate = t.join()
t.tick()
local seen = t.layers(mate, eng)
local found_worn = false
for _, layer in ipairs(seen) do
    if layer == "worn_toolbelt" then
        found_worn = true
    end
    if string.sub(layer, 1, 5) == "belt_" then
        error("bystander received object-only belt overlay " .. layer)
    end
end
assert(found_worn, "a bystander sees the directional worn belt")

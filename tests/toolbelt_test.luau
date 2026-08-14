-- An engineer signs on wearing a stocked toolbelt AND a backpack, and
-- the belt shows what is on it: pull the wrench out and the wrench
-- leaves the picture, put it back and it returns. The layer assertions
-- read what the CLIENT was told, not what the world holds — a belt
-- that composes correctly and never reaches the wire is still a bug.
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

-- The belt is worn, so the belt is drawn — and so is every tool on it
-- that tg gives a belt overlay. The welder and the coil have none in
-- tg's belt_overlays.dmi, so they have none here either.
assert(drawn("worn_toolbelt"), "the worn belt reached the wire")
assert(drawn("belt_wrench"), "the wrench shows on the belt")
assert(drawn("belt_screwdriver"), "so does the screwdriver")
assert(drawn("belt_crowbar"), "so does the crowbar")
assert(drawn("belt_cutters"), "so do the cutters")
assert(drawn("belt_multitool"), "so does the multitool")

-- Pull the wrench (row 2) into a hand: the belt's picture loses it.
t.take_from(eng, "belt", 2)
t.tick()
assert(t.hands(eng).held == "wrench", "the wrench is in hand")
assert(#t.stored(eng, "belt") == 6, "and off the belt")
assert(not drawn("belt_wrench"), "the wrench left the belt's picture")
assert(drawn("belt_screwdriver"), "the tools still on it are still drawn")
assert(drawn("worn_toolbelt"), "and the belt itself did not vanish")

-- Put it back: the picture answers again. This is the whole feature —
-- what an engineer is carrying is legible across the room.
t.store(eng, "belt")
t.tick()
assert(t.hands(eng).held == nil, "the hand is empty again")
assert(#t.stored(eng, "belt") == 7, "seven back on the belt")
assert(drawn("belt_wrench"), "and the wrench is back in the picture")

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
-- public, as in tg) but the belt is not a broadcast of its own rows to
-- the wearer alone — the second player sees the same composed picture.
local mate = t.join()
t.tick()
local seen = t.layers(mate, eng)
local found = false
for _, layer in ipairs(seen) do
    if layer == "belt_screwdriver" then
        found = true
    end
end
assert(found, "a bystander sees the tools on the belt too")

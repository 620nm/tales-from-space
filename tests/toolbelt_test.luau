-- An engineer signs on wearing a stocked toolbelt AND a backpack, and
-- the belt SHOWS ITS TOOLS on the wearer. That last part is a
-- deliberate divergence from tg, whose build_worn_icon draws a worn
-- belt barren (human_update_icons.dm:337-352 builds the mob overlay
-- alone; belt.dm:24-28 keeps the content overlays on the object) —
-- Josh ruled the tools show. Inventory rows still track every stored
-- tool, and the row LIST is still nobody else's business.
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
    items: [(3, 1, "toolbelt")],
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

-- The bulky stock rides the pack instead, the headset with it, and the
-- pocket oxygen bottle every outfit carries in front of both.
local pack = t.stored(eng, "back")
assert(table.concat(pack, ",") == "metal,floor_tile,emergency_tank.oxygen,headset",
    "the pack keeps what a belt cannot: " .. table.concat(pack, ","))

local function index_of(layers, name)
    for n, layer in ipairs(layers) do
        if layer == name then
            return n
        end
    end
    return nil
end

local function drawn(name, viewer, who)
    return index_of(t.layers(viewer or eng, who), name) ~= nil
end

local function belt_art(layers)
    local found = {}
    for _, layer in ipairs(layers) do
        if string.sub(layer, 1, 5) == "belt_" then
            table.insert(found, layer)
        end
    end
    return found
end

-- THE DIVERGENCE: the worn belt draws its contents over its own
-- directional worn icon, in storage order.
local mine = t.layers(eng)
local waist = index_of(mine, "worn_toolbelt")
assert(waist, "the worn belt reached the wire")
local previous = waist
for _, sprite in ipairs({
    "belt_screwdriver", "belt_wrench", "belt_crowbar",
    "belt_cutters", "belt_multitool",
}) do
    local at = index_of(mine, sprite)
    assert(at, sprite .. " is drawn on the wearer")
    assert(at > previous, sprite .. " draws over the belt, in storage order")
    previous = at
end

-- NEGATIVE: the picture is not the manifest. Seven tools ride the
-- belt; only the five with art of their own show. Nobody can count a
-- crewman's belt by looking at it, and the welder in there stays a
-- surprise.
assert(#belt_art(mine) == 5, "five pictures for seven tools")

-- The loose belt on the floor is unchanged: the object view composed
-- its contents before this divergence and composes them the same way
-- now, base sprite first.
local floor_belt = t.target_at(3, 1, "toolbelt")
assert(floor_belt, "a stocked belt lies on the deck")
local loose = t.layers(eng, floor_belt)
assert(loose[1] == "toolbelt", "the object's own picture is the base")
assert(table.concat(belt_art(loose), ",")
    == "belt_screwdriver,belt_wrench,belt_crowbar,belt_cutters,belt_multitool",
    "the object view still lists its tools in storage order")

-- Pull the wrench (row 2) into a hand: the belt loses that picture in
-- the SAME tick the inventory changes.
t.take_from(eng, "belt", 2)
t.tick()
assert(t.hands(eng).held == "wrench", "the wrench is in hand")
assert(#t.stored(eng, "belt") == 6, "and off the belt")
assert(drawn("worn_toolbelt"), "the belt itself did not vanish")
assert(not drawn("belt_wrench"), "the empty loop is empty on the wearer too")
assert(drawn("belt_crowbar"), "and the tools still on it are still drawn")

-- Put it back: the picture returns with the row.
t.store(eng, "belt")
t.tick()
assert(t.hands(eng).held == nil, "the hand is empty again")
assert(#t.stored(eng, "belt") == 7, "seven back on the belt")
assert(drawn("belt_wrench"), "and the wrench is drawn on the waist again")

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

-- Another crewman sees the whole waist: what a mob WEARS is public in
-- tg, and under this divergence the tools hanging off it are part of
-- that picture.
local mate = t.join()
t.tick()
local seen = t.layers(mate, eng)
assert(index_of(seen, "worn_toolbelt"), "a bystander sees the directional worn belt")
assert(index_of(seen, "belt_wrench"), "and the wrench hanging on it")

-- NEGATIVE: cosmetics are all a bystander gets. The overlays are five
-- for seven rows, so the stream still never discloses the belt's
-- CONTENTS — and pulling a tool changes the bystander's picture in the
-- same tick, without ever handing them a row.
assert(#belt_art(seen) == 5, "the bystander sees pictures, not a manifest")
local wrench_row
for n, id in ipairs(t.stored(eng, "belt")) do
    if id == "wrench" then
        wrench_row = n
    end
end
t.take_from(eng, "belt", assert(wrench_row, "the wrench is back on some row"))
t.tick()
assert(not drawn("belt_wrench", mate, eng), "the bystander's belt lost the wrench too")
assert(drawn("worn_toolbelt", mate, eng), "the belt itself stayed on")

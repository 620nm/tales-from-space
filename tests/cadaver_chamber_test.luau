-- A cadaver chamber as a crewman meets it: an obstacle while shut, a
-- slab that rolls out onto the aisle, a body and a dropped thing that
-- stop existing for everybody else the moment it shuts, the lamp that
-- says which of those is inside, and the push from within that opens
-- it again.
--
-- The concealment assertions are the security half: `t.items_at` and
-- `t.target_at` are what any second crewman in the room could see, and
-- a stowed thing has no tile at all, so there is nothing to filter.
--
-- The bay is wired, because a cadaver chamber is a corded appliance and
-- its lamps read power: on an unwired bench every one of them is dark.
-- The plant, the controller and the socket sit in the row behind the
-- rank, two cells of cord away (docs/POWER.md, "Outlets and cords").
-- `cadaver_power_test.luau` is the one that pulls the plug.
t.world([==[(
    name: "cadaver chamber bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
    },
    rows: [
        "#######",
        "#.....#",
        "#Gao..#",
        "#######",
    ],
    spawns: [(1, 1), (3, 1)],
    items: [(3, 1, "headset")],
    structures: [(2, 1, "cadaver_chamber", { "dir": "east" })],
    cables: [(1, 2, 2), (2, 2, 3), (3, 2, 1)],
)]==], 7)

local function has(rows, wanted)
    for _, row in ipairs(rows) do
        if row == wanted then return true end
    end
    return false
end

-- The first spawn is beside the drawer; the second is the tile it
-- opens onto, which is the only way a body gets onto a tray: stand
-- there and let the slab arrive under you.
local attendant = t.join()
local patient = t.join()
t.tick()
local ax, ay = t.pos(attendant)
assert(ax == 1 and ay == 1, "the attendant stands beside the drawer")
local px, py = t.pos(patient)
assert(px == 3 and py == 1, "the patient stands where the tray will be")

local drawer = t.target_at(2, 1, "cadaver_chamber")
assert(drawer ~= nil, "one targetable drawer")
local shut = t.structure_at(2, 1)
assert(shut.state == "closed" and shut.sprite == "morgue1_e",
    "it starts shut, wearing the empty face")
assert(#shut.overlays == 0, "an empty drawer wears no lamp")
assert(t.structure_at(3, 1) == nil, "a shut drawer's tray is nowhere")

-- Dense while shut, and dense while open: the drawer never stops
-- occupying its own tile, which is what makes a rank of them a wall.
t.move(attendant, "east")
t.run_ticks(3)
ax, ay = t.pos(attendant)
assert(ax == 1 and ay == 1, "the shut drawer blocks movement")

_ = t.sounds(attendant)
t.click(attendant, 2, 1, drawer)
t.tick()
local open = t.structure_at(2, 1)
assert(open.state == "open" and open.sprite == "morgue0_e",
    "opening selects the authored state and art")
assert(has(t.sounds(attendant), "morgue_clank"), "the tray is heard rolling")
local tray = t.structure_at(3, 1)
assert(tray ~= nil and tray.id == "cadaver_drawer" and tray.sprite == "morguet_e",
    "the slab lands on the tile the drawer faces")
px, py = t.pos(patient)
assert(px == 3 and py == 1, "the tray arrives under whoever is standing there")

-- Lie down on it, and let the attendant shut the drawer.
t.rest(patient)
_ = t.sounds(attendant)
t.click(attendant, 2, 1, drawer)
t.tick()
assert(t.structure_at(2, 1).state == "closed", "it shuts again")
assert(has(t.sounds(attendant), "morgue_clank"), "and is heard doing it")
assert(t.structure_at(3, 1) == nil, "the tray goes back in with everything on it")
assert(#t.items_at(3, 1) == 0, "the dropped thing is concealed")
assert(t.target_at(3, 1) == nil, "and there is nothing left on that tile to click")
assert(t.body_id(patient) ~= nil, "the body still exists; it simply has no tile")
-- The patient is a player who lay down on the slab and is very much
-- still going, so this is the `morgue4` lamp rather than the `morgue2`
-- one: tg lights it for an occupant a defibrillator could bring back
-- (morgue.dm:303-321, :384-403), and "has not stopped" is what that
-- reads as here. `cadaver_test.luau` is where a corpse lights the other.
assert(t.structure_at(2, 1).overlays[1] == "morgue4_e",
    "a drawer with somebody alive in it wears the living lamp")

-- tg's relaymove: a conscious body inside pushing any direction slides
-- it back out (morgue.dm:75-83).
t.move(patient, "west")
t.run_ticks(3)
assert(t.structure_at(2, 1).state == "open", "the push from inside opened it")
px, py = t.pos(patient)
assert(px == 3 and py == 1, "and put the patient back on the slab")
assert(has(t.items_at(3, 1), "headset"), "everything else came out with them")

-- Off the slab, and shut it on the dropped thing alone: the other lamp.
t.rest(patient, false)
t.run_ticks(3)
t.move(patient, "east")
t.run_ticks(4)
px, py = t.pos(patient)
assert(px == 4 and py == 1, "the patient steps clear of the slab")
t.move(patient, "west")
t.run_ticks(4)
px, py = t.pos(patient)
assert(px == 4 and py == 1, "and cannot step back onto it: an open tray is dense")

t.click(attendant, 2, 1, drawer)
t.tick()
assert(#t.items_at(3, 1) == 0, "the dropped thing is inside")
assert(t.structure_at(2, 1).overlays[1] == "morgue3_e",
    "things but nobody is the other lamp")

assert(#t.ledger_rows("drawer_opened") == 2, "both opens are attributed")
assert(#t.ledger_rows("drawer_closed") == 2, "both closes are attributed")
assert(t.ledger_has("DrawerClosed", "cadaver chamber"), "the row names the thing")

-- A drawer with nowhere to put its tray refuses, says so, and is still
-- an obstacle afterwards.
--
-- Wired for the same reason the bench above is: this one is about the
-- refusal, not about power, and an unfed chamber here would be a true
-- `corded fixture has no outlet within cord range` warning drowning out
-- the one bench that means to trip it.
t.world([==[(
    name: "walled cadaver chamber bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
    },
    rows: [
        "#####",
        "#..##",
        "#Gao#",
        "#####",
    ],
    spawns: [(1, 1)],
    items: [],
    structures: [(2, 1, "cadaver_chamber", { "dir": "east" })],
    cables: [(1, 2, 2), (2, 2, 3), (3, 2, 1)],
)]==], 7)

local crew = t.join()
t.tick()
local walled = t.target_at(2, 1, "cadaver_chamber")
_ = t.messages(crew)
t.click(crew, 2, 1, walled)
t.tick()
assert(t.structure_at(2, 1).state == "closed", "a drawer facing a wall stays shut")
assert(#t.messages(crew) > 0, "and says why")
t.move(crew, "east")
t.run_ticks(3)
local cx, cy = t.pos(crew)
assert(cx == 1 and cy == 1, "a refused drawer is still an obstacle")

-- ---- dragging somebody onto the slab --------------------------------
-- tg lets you stuff a body into a cadaver drawer: the tray's own
-- `mouse_drop_receive` force-moves an unbuckled mob onto the tray's
-- tile (code/game/objects/structures/morgue.dm:582-594). Here the
-- engine's drag seam has an arm for the tray, and it is the same timed
-- lay every other surface gets -- two seconds, tg's own number for
-- putting somebody somewhere (bin.dm:225).
--
-- The slab is DENSE, which is the interesting part: an open tray is an
-- obstacle you cannot walk onto (the assertion further up says so), and
-- the thing you are being laid ONTO is the one thing that never blocks
-- the drop.
t.world([==[(
    name: "cadaver chamber aisle",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
    },
    rows: [
        "#######",
        "#.....#",
        "#.....#",
        "#Gao..#",
        "#######",
    ],
    spawns: [(3, 2), (4, 1)],
    structures: [(2, 1, "cadaver_chamber", { "dir": "east" })],
    cables: [(1, 3, 2), (2, 3, 3), (3, 3, 1)],
)]==], 7)

local LAY_TICKS = 2 * 20 + 2

local orderly = t.join()
local corpse = t.join()
t.tick()
assert(t.pos(orderly) == 3, "the orderly stands in the aisle")
local cx, cy = t.pos(corpse)
assert(cx == 4 and cy == 1, "and the body beside the slab's tile")

local bay = t.target_at(2, 1, "cadaver_chamber")
t.click(orderly, 2, 1, bay)
t.tick()
local slab = t.target_at(3, 1, "cadaver_drawer")
assert(slab ~= nil, "the slab is out on the deck")

-- Nothing lands in the tick the drag arrives.
t.drag(orderly, 4, 1, t.body_id(corpse), 3, 1, slab)
t.run_ticks(2)
cx, cy = t.pos(corpse)
assert(cx == 4 and cy == 1, "two ticks in, the body has not moved")

t.run_ticks(LAY_TICKS)
cx, cy = t.pos(corpse)
assert(cx == 3 and cy == 1, "the body is on the slab: " .. cx .. "," .. cy)
assert(t.body(corpse).posture == "lying", "lying on it")

-- ...and that is already everything the close needs. A body on the
-- tray's tile is what `close_drawer` gathers; the drag added no second
-- mechanism.
t.click(orderly, 2, 1, bay)
t.tick()
assert(t.structure_at(2, 1).state == "closed", "the drawer shuts on them")
assert(t.structure_at(3, 1) == nil, "the slab went back in")
assert(t.target_at(3, 1) == nil,
    "a stowed body has no tile at all: there is nothing left to click")
assert(t.body_id(corpse) ~= nil, "the body still exists")
assert(t.structure_at(2, 1).overlays[1] == "morgue4_e",
    "and the drawer wears the lamp for somebody still going")

print("cadaver chamber: obstacle, slab, concealment, lamps, the push out, "
    .. "and a body dragged onto the slab")

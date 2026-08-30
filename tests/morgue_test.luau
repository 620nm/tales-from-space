-- A morgue drawer as a crewman meets it: an obstacle while shut, a
-- slab that rolls out onto the aisle, a body and a dropped thing that
-- stop existing for everybody else the moment it shuts, the lamp that
-- says which of those is inside, and the push from within that opens
-- it again.
--
-- The concealment assertions are the security half: `t.items_at` and
-- `t.target_at` are what any second crewman in the room could see, and
-- a stowed thing has no tile at all, so there is nothing to filter.
t.world([==[(
    name: "morgue bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#######",
        "#.....#",
        "#######",
    ],
    spawns: [(1, 1), (3, 1)],
    items: [(3, 1, "headset")],
    structures: [(2, 1, "morgue", { "dir": "east" })],
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

local drawer = t.target_at(2, 1, "morgue")
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
assert(tray ~= nil and tray.id == "morgue_tray" and tray.sprite == "morguet_e",
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
assert(t.structure_at(2, 1).overlays[1] == "morgue2_e",
    "a drawer with somebody in it wears the body lamp")

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
assert(t.ledger_has("DrawerClosed", "morgue"), "the row names the thing")

-- A drawer with nowhere to put its tray refuses, says so, and is still
-- an obstacle afterwards.
t.world([==[(
    name: "walled morgue bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "####",
        "#..#",
        "####",
    ],
    spawns: [(1, 1)],
    items: [],
    structures: [(2, 1, "morgue", { "dir": "east" })],
)]==], 7)

local crew = t.join()
t.tick()
local walled = t.target_at(2, 1, "morgue")
_ = t.messages(crew)
t.click(crew, 2, 1, walled)
t.tick()
assert(t.structure_at(2, 1).state == "closed", "a drawer facing a wall stays shut")
assert(#t.messages(crew) > 0, "and says why")
t.move(crew, "east")
t.run_ticks(3)
local cx, cy = t.pos(crew)
assert(cx == 1 and cy == 1, "a refused drawer is still an obstacle")

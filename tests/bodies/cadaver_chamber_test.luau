-- A cadaver chamber as a crewman meets it: an obstacle while shut, walkable
-- open, a lying body and a dropped thing that stop existing for everybody else
-- the moment it shuts, the push from within that opens it again and slides
-- them out onto the tile it faces, the close that takes them back off it, the
-- lamp for things and nobody, the four-second stuff from the next tile, and a
-- chamber facing a wall that keeps what it held on its own tile.
--
-- The concealment assertions are the security half: `t.items_at` and
-- `t.target_at` are what any second crewman in the room could see, and a
-- stowed thing has no tile at all, so there is nothing to filter.
--
-- The bay is wired, because a cadaver chamber is a corded appliance and its
-- lamps read power. The plant, the controller and the socket sit in the row
-- behind the rank, two cells of cord away (docs/POWER.md, "Outlets and cords").
-- `cadaver_power_test.luau` is the one that pulls the plug.
local clock = require("@helpers/clock")
t.world(
    [==[(
    name: "cadaver chamber bench",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
    },
    levels: [
        (
            rows: [
                "#######",
                "#.....#",
                "#Gao..#",
                "#######",
            ],
            items: [(2, 1, "headset")],
            structures: [(1, 1, "player_spawn", { "jobs": "medic" }), (3, 1, "player_spawn", { "jobs": "assistant" }), (2, 1, "cadaver_chamber"), (2, 2, "apc")],
            networks: [
                (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
            ],
        ),
    ],
)]==],
    7
)

local function has(rows, wanted)
    for _, row in ipairs(rows) do
        if row == wanted then
            return true
        end
    end
    return false
end

local WATCH_TICKS = clock.deadline_ticks(1.0) + 2

local attendant = t.join("medic")
local patient = t.join("assistant")
t.tick()
local ax, ay = t.pos(attendant)
assert(ax == 1 and ay == 1, "the attendant stands beside the chamber")
local px, py = t.pos(patient)
assert(px == 3 and py == 1, "the patient stands on its far side")

local chamber = t.target_at(attendant, 2, 1, "cadaver_chamber")
assert(chamber ~= nil, "one targetable chamber")
local shut = assert(t.structure_at(2, 1))
assert(shut.state == "closed" and shut.sprite == "morgue1_s", "it starts shut, wearing the empty face")

t.move(attendant, "east")
t.run_ticks(3)
ax, ay = t.pos(attendant)
assert(ax == 1 and ay == 1, "the shut chamber blocks movement")

t.sounds(attendant)
t.click(attendant, 2, 1, chamber)
t.tick()
local open = assert(t.structure_at(2, 1))
assert(open.state == "open" and open.sprite == "morgue0_s", "opening selects the authored state and art")
assert(has(t.sounds(attendant), "morgue_clank"), "the slab is heard")

-- Open it is walkable; a body lies down where it stands.
t.move(patient, "west")
t.run_ticks(4)
px, py = t.pos(patient)
assert(px == 2 and py == 1, "an open chamber can be walked onto")
t.rest(patient)
t.run_ticks(2)
t.sounds(attendant)
t.click(attendant, 2, 1, chamber)
t.tick()
assert(assert(t.structure_at(2, 1)).state == "closed", "it shuts again")
assert(has(t.sounds(attendant), "morgue_clank"), "and is heard doing it")
assert(#t.items_at(2, 1) == 0, "the dropped thing is concealed")
assert(#t.bodies_at(2, 1) == 0, "and so is the body")
assert(t.target_at(attendant, 2, 1, "headset") == nil, "there is no item left on that tile to click")
assert(t.body_id(patient) ~= nil, "the body still exists; it simply has no tile")

-- Somebody going keeps the plain shut face: no lamp takes their push away.
t.run_ticks(WATCH_TICKS)
local holding = assert(t.structure_at(2, 1))
assert(
    holding.state == "closed" and holding.sprite == "morgue1_s",
    "a chamber with somebody alive in it stays exactly closed"
)

-- tg's relaymove: a conscious body inside pushing any direction opens it
-- (morgue.dm:75-83).
t.move(patient, "west")
t.run_ticks(3)
assert(assert(t.structure_at(2, 1)).state == "open", "the push from inside opened it")
-- tg's `open()` puts what it held on the tray's turf (morgue.dm:141-144).
px, py = t.pos(patient)
assert(px == 2 and py == 2, "and slid the patient out onto the tile it faces")
assert(has(t.items_at(2, 2), "headset"), "everything else came out with them")
assert(#t.items_at(2, 1) == 0, "leaving the slab bare")

-- A standing body on the slab is refused, and says so. The push cost a lying
-- step, which the wait pays off.
t.rest(patient, false)
t.run_seconds(1)
t.move(patient, "north")
t.run_ticks(4)
px, py = t.pos(patient)
assert(px == 2 and py == 1, "the patient climbs back onto the slab")
t.messages(attendant)
t.click(attendant, 2, 1, chamber)
t.tick()
assert(assert(t.structure_at(2, 1)).state == "open", "a standing body keeps it open")
assert(#t.messages(attendant) > 0, "and the closer is told why")

-- Off the slab, and shut it on the dropped thing alone: the close takes it
-- back off the tray's tile (`close()`, morgue.dm:149-169), and the lit state.
t.run_seconds(1)
t.move(patient, "east")
t.run_ticks(4)
px, py = t.pos(patient)
assert(px == 3 and py == 1, "the patient steps clear")
t.click(attendant, 2, 1, chamber)
t.run_ticks(WATCH_TICKS)
local lit = assert(t.structure_at(2, 1))
assert(lit.state == "closed_items" and lit.sprite == "morgue3_s", "things and nobody is the items lamp")
assert(#t.items_at(2, 2) == 0, "the dropped thing is inside")
assert(t.target_at(attendant, 2, 2, "headset") == nil, "and a lit chamber leaves nothing to click")

-- A click steps the lamp back to `closed`, which is the only state that opens.
t.click(attendant, 2, 1, chamber)
t.run_ticks(2)
assert(assert(t.structure_at(2, 1)).state == "open", "a lit chamber opens to a click")
assert(has(t.items_at(2, 2), "headset"), "and slides the thing back out")

assert(#t.ledger_rows("container_opened") == 3, "every open is attributed")
assert(#t.ledger_rows("container_closed") == 2, "every close is attributed")
assert(t.ledger_has("ContainerClosed", "cadaver chamber"), "the row names the thing")
assert(#t.script_errors() == 0, "the chamber's handlers run cleanly")

-- Somebody standing on the tray's tile is slid in by the close, as tg's
-- `close()` takes any living mob there (morgue.dm:157-167); only one standing
-- on the slab itself refuses it.
t.move(patient, "south")
t.run_ticks(4)
t.move(patient, "west")
t.run_ticks(4)
px, py = t.pos(patient)
assert(px == 2 and py == 2, "the patient stands on the tray's tile")
t.click(attendant, 2, 1, chamber)
t.tick()
assert(assert(t.structure_at(2, 1)).state == "closed", "the chamber shuts with them standing there")
assert(#t.bodies_at(2, 2) == 0 and #t.items_at(2, 2) == 0, "and takes them in with the headset")
assert(t.body_id(patient) ~= nil, "the body has no tile, but exists")

-- ---- stuffing somebody in from the next tile --------------------------
-- The closet's drag: four seconds, then the close takes the body off its own
-- tile (lib/body_drag.luau). tg's own body drag is onto the tray
-- (morgue.dm:589-601), which is not ported.
t.world(
    [==[(
    name: "cadaver chamber aisle",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
    },
    levels: [
        (
            rows: [
                "#######",
                "#.....#",
                "#.....#",
                "#Gao..#",
                "#######",
            ],
            structures: [(3, 2, "player_spawn", { "jobs": "medic" }), (3, 1, "player_spawn", { "jobs": "assistant" }), (2, 1, "cadaver_chamber"), (2, 3, "apc")],
            networks: [
                (x: 1, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 2, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 2, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 3, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
            ],
        ),
    ],
)]==],
    7
)

local orderly = t.join("medic")
local stuffed = t.join("assistant")
t.tick()

local bay = t.target_at(orderly, 2, 1, "cadaver_chamber")
t.click(orderly, 2, 1, bay)
t.tick()
assert(assert(t.structure_at(2, 1)).state == "open", "the chamber stands open")

-- Nothing lands in the tick the drag arrives.
t.sounds(orderly)
t.drag(orderly, 3, 1, assert(t.body_target(orderly, stuffed)), 2, 1, assert(bay))
t.run_ticks(2)
local cx, cy = t.pos(stuffed)
assert(cx == 3 and cy == 1, "two ticks in, the body has not moved")

t.run_ticks(clock.deadline_ticks(4.0) + 3)
assert(assert(t.structure_at(2, 1)).state == "closed", "the chamber shuts on them")
assert(#t.bodies_at(3, 1) == 0, "a stowed body has no tile at all")
assert(t.body_id(stuffed) ~= nil, "the body still exists")
assert(assert(t.body(stuffed)).posture == "lying", "and was knocked down going in")

-- The drag's close starts the same watch a click's does.
t.run_ticks(WATCH_TICKS)
assert(has(t.sounds(orderly), "cadaver_alert"), "the alarm answers somebody stuffed in alive")
t.set_health(stuffed, { burn = 200 })
t.run_ticks(WATCH_TICKS)
assert(assert(t.structure_at(2, 1)).state == "closed_bodies", "and the lamp lights once they stop")
assert(#t.script_errors() == 0, "the stuff runs cleanly")

-- ---- a chamber facing a wall ------------------------------------------
-- Nothing steps into a wall, so what it held stays on the chamber's own tile;
-- tg's `forceMove` puts it on the tray's turf whatever stands there
-- (morgue.dm:141-144). Unwired: the lamps are not the claim.
t.world(
    [==[(
    name: "cadaver chamber against a wall",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "#####",
                "#...#",
                "#####",
            ],
            items: [(2, 1, "headset")],
            structures: [(1, 1, "player_spawn", { "jobs": "medic" }), (2, 1, "cadaver_chamber")],
        ),
    ],
)]==],
    7
)

local keeper = t.join("medic")
t.tick()
local walled = t.target_at(keeper, 2, 1, "cadaver_chamber")
t.click(keeper, 2, 1, walled)
t.tick()
t.click(keeper, 2, 1, walled)
t.tick()
assert(assert(t.structure_at(2, 1)).state == "closed", "it shuts on the headset")
assert(#t.items_at(2, 1) == 0, "which is inside")
t.click(keeper, 2, 1, walled)
t.run_ticks(2)
assert(assert(t.structure_at(2, 1)).state == "open", "it opens again")
assert(has(t.items_at(2, 1), "headset"), "and the wall keeps the headset on the slab")
assert(#t.script_errors() == 0, "the walled chamber runs cleanly")

print("cadaver chamber: obstacle, walkable open, concealment, the push out onto the tray's tile, the items lamp, the stuff, a wall")

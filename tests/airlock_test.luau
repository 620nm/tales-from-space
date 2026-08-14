-- The EVA vestibule: two airlocks with three tiles of plating between
-- them, so the way out to space is a chamber you empty rather than a
-- hole you open.
--
-- Shape copied from tgstation's MetaStation "Escape Pod One"
-- (_maps/map_files/MetaStation/MetaStation.dmm, (38,147)-(38,149)): an
-- /obj/machinery/door/airlock/external at each end of a three-tile
-- /turf/open/floor/plating chamber, hull all the way round.
--
-- What tg has and this does NOT: the doors are cycle-linked there
-- (/obj/effect/mapping_helpers/airlock/cyclelink_helper, resolved by
-- /obj/machinery/door/airlock/proc/cyclelinkairlock in
-- code/game/machinery/doors/airlock.dm:225), so opening one shuts the
-- other. Here they are two independent doors. The vestibule therefore
-- protects the station by GEOMETRY and crew discipline, and this spec
-- pins both halves of that: one door open keeps the air in, two doors
-- open do not. The second assertion is the one that would catch a
-- vestibule wired up wrong -- a chamber that "works" because it never
-- vented at all proves nothing.

-- A station room, an inner airlock, three tiles of vestibule, an outer
-- airlock, and space. Chamber column x = 6, doors at (5, 2) and (7, 2).
local VESTIBULE = [==[(
    name: "eva vestibule",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        '_': (turf: Plating),
        'E': (turf: Plating, fixture: Some(Door)),
    },
    rows: [
        "######## ",
        "#....#_# ",
        "#....E_E ",
        "#....#_# ",
        "######## ",
    ],
    spawns: [(1, 2), (2, 2)],
)]==]

-- Walk east out of the room, through the inner airlock (bump opens it),
-- and stand in the middle of the vestibule at (6, 2).
local function walk_east(p, n)
    for _ = 1, n do
        t.move(p, "east")
        t.run_ticks(5) -- a step is rate-limited; give the cooldown room
    end
end

-- A click TOGGLES an airlock, so "hold it open" means click it only
-- when it has shut itself. This is a crewman keeping their hand on the
-- door while the chamber empties, nothing more.
local function hold_open(p, x, y, rounds)
    for _ = 1, rounds do
        if not t.door_at(x, y).open then
            t.click(p, x, y)
        end
        t.run_ticks(10)
    end
end

local function step_into_the_chamber(p)
    walk_east(p, 4) -- across the room, then bump the inner airlock open
    assert(t.door_at(5, 2).open, "bumping the inner airlock opened it")
    walk_east(p, 2) -- through the doorway into the vestibule
    local x, y = t.pos(p)
    assert(x == 6 and y == 2, "standing in the vestibule, not " .. x .. "," .. y)
end

-- ---------------------------------------------------------------
-- One door at a time: the vestibule vents, the station does not.
-- ---------------------------------------------------------------
t.world(VESTIBULE, 7)
local p = t.join()
t.tick()

assert(t.turf(6, 2) == "plating", "the vestibule deck is bare, as tg's is")
assert(t.turf(8, 2) == "space", "and the outer airlock opens onto space")
assert(not t.door_at(5, 2).open and not t.door_at(7, 2).open,
    "both airlocks start shut")
assert(t.room_pressure(2, 2) > 90.0, "the station starts breathable")
assert(t.room_pressure(6, 2) > 90.0,
    "and so does the vestibule -- it is a room that holds air, not a hole")

step_into_the_chamber(p)

-- Let the inner airlock shut behind us. Nobody is standing in the
-- doorway, so the autoclose takes.
t.run_ticks(65)
assert(not t.door_at(5, 2).open, "the inner airlock shut behind us")
assert(t.room_pressure(6, 2) > 90.0, "the sealed chamber kept its air")

-- Now open the outer airlock, with the inner one shut.
t.click(p, 7, 2)
t.tick()
assert(t.door_at(7, 2).open, "the outer airlock opened")
-- Held open past its autoclose while the chamber empties. Three tiles
-- of one atmosphere take a while to leave through one doorway, which
-- is itself the reason a vestibule works.
hold_open(p, 7, 2, 60)

assert(t.room_pressure(6, 2) < 25.0,
    "the vestibule blew out to space: " .. t.room_pressure(6, 2))
assert(t.room_pressure(2, 2) > 90.0,
    "and THE STATION DID NOT VENT: " .. t.room_pressure(2, 2))
assert(t.room_pressure(1, 1) > 90.0, "not in any corner of it")

-- ---------------------------------------------------------------
-- Both doors at once: the same geometry with the discipline removed.
-- ---------------------------------------------------------------
t.world(VESTIBULE, 7)
local q = t.join()
t.tick()
local before = t.room_pressure(2, 2)
assert(before > 90.0, "same station, same starting atmosphere")

step_into_the_chamber(q)

-- The inner airlock is still standing open behind us -- nothing has
-- shut it, because nothing links these two doors. Open the outer one
-- on top of that and the station is a straight line to vacuum.
assert(t.door_at(5, 2).open, "the inner airlock is still open behind us")
t.click(q, 7, 2)
t.tick()
assert(t.door_at(7, 2).open, "and the outer one opens anyway")

-- Trip the breaker so both stay where they are: dead motors hold
-- whatever position they had, so this is the vestibule wedged open
-- rather than a spec poking the sim. (The crewman standing in it will
-- be dragged out by the wind long before it settles, which is rather
-- the point of the assertion.)
t.outage()
t.run_ticks(2400)
assert(t.door_at(5, 2).open and t.door_at(7, 2).open,
    "unpowered airlocks have no motors to shut themselves with")

local after = t.room_pressure(2, 2)
assert(after < before - 10.0,
    "with both airlocks open the station vents through the vestibule: "
        .. before .. " -> " .. after)

-- (Chillstation's own vestibule, east of the Annex, is pinned in
-- crates/lunatic-server/src/sim/tests/chill.rs, where the rest of that
-- map's roundstart assertions already live.)

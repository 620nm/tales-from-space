-- The EVA vestibule: two airlocks with three tiles of plating between
-- them, so the way out to space is a chamber you empty rather than a
-- hole you open.
--
-- Shape copied from tgstation's MetaStation "Escape Pod One"
-- (_maps/map_files/MetaStation/MetaStation.dmm, (38,147)-(38,149)): an
-- /obj/machinery/door/airlock/external at each end of a three-tile
-- /turf/open/floor/plating chamber, hull all the way round.
--
-- The spec runs the same chamber TWICE over, as a control and as the
-- real thing:
--
--   1. Unlinked -- two independent doors. Geometry alone: one door open
--      keeps the station's air, two doors open do not. The second
--      assertion is what catches a vestibule wired up wrong, because a
--      chamber that "works" by never venting at all proves nothing.
--   2. Cycle-linked -- the map's `cycle_links` naming each door's
--      partner (tg's /obj/effect/mapping_helpers/airlock/cyclelink_
--      helper, resolved by /obj/machinery/door/airlock/proc/
--      cyclelinkairlock, code/game/machinery/doors/airlock.dm:225, and
--      acted on when a door opens at :1357). Now the second door
--      cannot be held open on top of the first, so the station is safe
--      from an impatient crewman and not merely from a careful one.
--
-- Same map, one field of difference, opposite outcomes. That is the
-- whole argument for the feature.

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

-- The same chamber, interlocked. Each airlock names the direction its
-- partner lies in, and the link resolves only because both of them do
-- (airlock.dm:235 throws away a door that does not point back).
local LINKED = VESTIBULE:gsub(
    "spawns: %[%(1, 2%), %(2, 2%)%],",
    "spawns: [(1, 2), (2, 2)],\n    cycle_links: [(5, 2, East), (7, 2, West)],"
)

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

-- ---------------------------------------------------------------
-- The same chamber, cycle-linked: the discipline becomes machinery.
-- ---------------------------------------------------------------
t.world(LINKED, 7)
local r = t.join()
t.tick()
local linked_before = t.room_pressure(2, 2)
assert(linked_before > 90.0, "same station, same starting atmosphere")

walk_east(r, 4)
assert(t.door_at(5, 2).open, "bumping the inner airlock still opens it")
walk_east(r, 2)
local rx, ry = t.pos(r)
assert(rx == 6 and ry == 2, "standing in the vestibule, not " .. rx .. "," .. ry)
assert(t.door_at(5, 2).open,
    "and the inner airlock is still open behind us -- nothing has asked "
        .. "it to shut yet")

-- Here is the whole feature. Opening the outer airlock CLOSES the inner
-- one, without anybody deciding to be careful (airlock.dm:1357).
t.click(r, 7, 2)
t.tick()
assert(t.door_at(7, 2).open, "the outer airlock opened")
assert(not t.door_at(5, 2).open,
    "AND THE INNER ONE SHUT ITSELF: opening one end of a cycle-linked "
        .. "airlock closes the other")

-- Now do exactly what vented the station in the control run: hold the
-- outer door open, with the breaker pulled so nothing can tidy up after
-- us, and watch the chamber empty on its own.
hold_open(r, 7, 2, 60)
t.outage()
t.run_ticks(2400)

assert(t.room_pressure(6, 2) < 25.0,
    "the chamber still empties -- an interlock is not a plug: "
        .. t.room_pressure(6, 2))
local linked_after = t.room_pressure(2, 2)
assert(linked_after > 90.0,
    "and the station never lost its air, because the two doors were "
        .. "never open together: " .. linked_before .. " -> " .. linked_after)

-- ---------------------------------------------------------------
-- A window is a barrier. Glass in a hull holds an atmosphere back,
-- and taking it out is a breach with no breach state behind it.
-- ---------------------------------------------------------------
--
-- tg: /obj/structure/window/can_atmos_pass (code/game/objects/
-- structures/window.dm:405) returns false while the pane is anchored,
-- dense and fulltile, which is what makes a viewport a viewport. Here
-- that is one `airtight` line in tfs/content/structures/grille.luau and
-- a map placing the grille in a glazed state.
--
-- A sealed room with one tile of its north hull replaced by plating,
-- with a window standing on it, and a screwdriver and crowbar on the
-- floor -- the fourteen seconds tg charges for a plain pane.
local VIEWPORT = [==[(
    name: "viewport",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        '_': (turf: Plating),
    },
    rows: [
        "     ",
        "     ",
        "##_##",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 3), (1, 3)],
    items: [
        (2, 4, "screwdriver"),
        (3, 4, "crowbar"),
    ],
    structures: [(2, 2, "grille", "glazed")],
)]==]

t.world(VIEWPORT, 7)
local w = t.join()
t.tick()

local pane = t.structure_at(2, 2)
assert(pane and pane.id == "grille",
    "the map stood a grille in the hull gap")
assert(pane.state == "glazed",
    "AND IT SHIPPED GLAZED: a map may place a structure in a named "
        .. "state, so a station can boot with windows in it "
        .. "(got " .. tostring(pane and pane.state) .. ")")
assert(t.turf(2, 2) == "plating", "a window stands on deck, not on wall")
assert(t.turf(2, 1) == "space", "with vacuum on the far side of it")

-- One atmosphere, and it stays there. Before `airtight` this room was
-- open to space through a tile that merely looked solid.
t.run_ticks(600)
local sealed = t.room_pressure(2, 3)
assert(sealed > 90.0,
    "A WINDOW IN A HULL HOLDS PRESSURE: " .. sealed)

-- Take it out, the long way, with the tools tg asks for: four seconds
-- of screwdriver to unseal the pane, ten of crowbar to lever it free.
-- Every step is a click a player could make.
t.click(w, 2, 4) -- pick up the screwdriver
t.tick()
assert(t.hands(w).held == "screwdriver", "screwdriver in hand")
t.click(w, 2, 2)
t.run_ticks(100)
assert(t.structure_at(2, 2).state == "unsealed",
    "the pane is loose in its frame")
-- Loose is still glass in a frame, and tg agrees: the room is not open
-- to space until the pane actually comes out.
assert(t.room_pressure(2, 3) > 90.0,
    "an unscrewed pane is still a pane: " .. t.room_pressure(2, 3))

t.swap_hands(w) -- the screwdriver stays in the other hand
t.click(w, 3, 4) -- and now the crowbar
t.tick()
assert(t.hands(w).held == "crowbar", "crowbar in hand")
t.click(w, 2, 2)
t.run_ticks(240)
assert(t.structure_at(2, 2).state == "bolted",
    "the pane came free and left the bare grille standing")

-- And THAT is a breach -- computed, not declared. Nothing anywhere
-- stores "broken window"; a barrier simply stopped sealing, and the
-- matter engine did the rest.
t.run_ticks(1200)
local vented = t.room_pressure(2, 3)
assert(vented < 25.0,
    "PULLING THE PANE VENTS THE ROOM: " .. sealed .. " -> " .. vented)

-- (Chillstation's own vestibule and its viewports are pinned in
-- crates/lunatic-server/src/sim/tests/chill.rs, where the rest of that
-- map's roundstart assertions already live.)

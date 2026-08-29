-- A pump with no wire under it, and the socket across the room that
-- runs it.
--
-- Atmospherics kit is bolted down where the PLUMBING wants it. A run
-- goes where the departments are, the machines that stand in it go
-- where the run does, and none of that has ever consulted the
-- electrician: requiring a cable under every pump made the grid a
-- hidden second constraint on the pipe layout that no map could see,
-- and the failure it produced was the worst kind -- a machine that
-- looked bolted down and correct and simply never ran.
--
-- So a pipe machine draws the way everything else in a room does
-- (docs/POWER.md, "Outlets and cords"): the wire under its own tile
-- where there is one, and otherwise a cord to the nearest socket
-- passing equipment within `cord_range`. Same BFS as a lamp's, same
-- walls, same closed doors, same six cells.
--
-- power_ports_test.luau owns what a socket IS and pump_socket_test.luau
-- owns the plumbing fit that shares its name. What is here is only the
-- reach: one pump inside it, one pump past it, and the same map.

local function readout(p, label)
    for _, r in ipairs(t.ui(p).readouts) do
        if r.label == label then
            return r.value
        end
    end
    return nil
end

-- The room circuit stops at the socket at (3, 2) and there is no cable
-- east of it at all. Two volumetric pumps stand on that bare deck, both
-- mapped running, both plumbed the same way: a charged main behind them
-- and a length of empty pipe in front. The only thing that differs
-- between the two is how far they are from the socket -- three cells,
-- and eight.
t.world([==[(
    name: "a pump on a cord",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'G': (turf: Plating, fixture: Some(Generator)),
        'a': (turf: Plating, fixture: Some(Apc)),
        'o': (turf: Plating, fixture: Some(Outlet)),
    },
    rows: [
        "##############",
        "#G...........#",
        "#a.o.........#",
        "##############",
    ],
    spawns: [(6, 1)],
    pipes: [
        (4, 2, 4), (5, 2, 4), (7, 2, 4),
        (9, 2, 4), (10, 2, 4), (12, 2, 4),
    ],
    structures: [
        (6, 2, "volume_pump", "running", { "dir": "east" }),
        (11, 2, "volume_pump", "running", { "dir": "east" }),
    ],
    cables: [
        (1, 1, 2), (1, 2, 2),
        (1, 2, 1), (2, 2, 1), (3, 2, 1),
    ],
)]==], 7)

local p = t.join()
t.tick()

-- Both mains, as the map commissioned them and before anything has had
-- a chance to move a mole. The boot settles the grid before the first
-- tick, so the far pump has never been fed for an instant.
local charged = t.pipe_pressure(4, 2)
local far = t.pipe_pressure(9, 2)
assert(charged > 90.0, "the near main opened the shift commissioned: " .. charged)
assert(far > 90.0, "and so did the far one: " .. far)

assert(t.cable_at(6, 2) == 0, "there is no wire under the near pump at all")
assert(t.cable_at(11, 2) == 0, "nor under the far one")
assert(t.structure_at(6, 2).id == "volume_pump", "the map stood one there")

-- ---------------------------------------------------------------
-- THREE CELLS FROM THE SOCKET: CORDED, AND IT RUNS.
--
-- The panel says `fed` and the gas says the same thing: a volumetric
-- pump has no notion of arriving, so a main whose only outlet is this
-- machine ends EMPTY. Nothing else on this map can move a mole.
-- ---------------------------------------------------------------
t.click(p, 6, 2, t.target_at(6, 2, "volume_pump"))
t.tick()
assert(readout(p, "supply") == "fed", "the socket across the room is behind it")
t.ui_close(p)
t.tick()

assert(
    t.structure_at(6, 2).sprite == "volpump_on_e",
    "and it is drawn running: " .. tostring(t.structure_at(6, 2).sprite)
)

t.run_seconds(60)
local drained = t.pipe_pressure(4, 2)
assert(
    drained < charged * 0.05,
    "the corded pump emptied its main into the run in front of it: "
        .. charged .. " -> " .. drained
)
assert(t.pipe_pressure(7, 2) > charged, "which is where it went")

-- ---------------------------------------------------------------
-- EIGHT CELLS FROM IT: PAST THE END OF THE CORD.
--
-- `cord_range` is six (content/tuning.luau; the suite pins the engine's
-- own six). The far pump is switched on, plumbed identically, and dead
-- -- and it is drawn dead, which is the whole point of the picture rule
-- being `working()` and not `on`.
-- ---------------------------------------------------------------
assert(
    t.structure_at(11, 2).sprite == "volpump_off_e",
    "and it is drawn dead: " .. tostring(t.structure_at(11, 2).sprite)
)
assert(
    math.abs(t.pipe_pressure(9, 2) - far) < 0.001,
    "sixty seconds and it has moved nothing: " .. far .. " -> " .. t.pipe_pressure(9, 2)
)

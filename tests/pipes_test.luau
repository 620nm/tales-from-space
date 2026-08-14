-- Plumbing, from both ends: a player runs a line and pulls it up, and
-- gas crosses a station through the line somebody else already ran.
--
-- Layer masks are tg's five piping layers; 4 is layer 3, the
-- distribution run.
local DISTRO = 4

local function said(p, want)
    for _, m in ipairs(t.messages(p)) do
        if m == want then
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------
-- Laying and pulling. The room is bare plating, because pipe goes
-- UNDER the deck and a finished floor is refused.
-- ---------------------------------------------------------------
t.world([==[(
    name: "plumbing",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        'o': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#.o.#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [
        (1, 1, "pipe"),
        (3, 3, "wrench"),
    ],
)]==], 7)

local p = t.join()
t.tick()

-- Pick up the coil of pipe and run three lengths west to east.
t.click(p, 1, 1)
t.run_ticks(2)
for _, x in ipairs({ 1, 2, 3 }) do
    t.click(p, x, 1)
    t.run_seconds(1.5)
end
assert(t.pipe(1, 1) == DISTRO, "a length went down at the west end")
assert(t.pipe(2, 1) == DISTRO, "and through the middle")
assert(t.pipe(3, 1) == DISTRO, "and out the east end")
assert(t.ledger_has("PipeLaid"), "every length is on the record")

-- The finished floor in the middle of the room refuses a length: pipe
-- is subfloor work and the tile has to be open.
local _ = t.messages(p)
t.click(p, 2, 2)
t.run_ticks(4)
assert(t.pipe(2, 2) == 0, "no length under a finished floor")
assert(
    said(p, "The floor is in the way. Pry the tile up first."),
    "and the refusal says what to do about it"
)

-- A run a player builds starts empty -- nobody filled it.
assert(t.pipe_pressure(2, 1) ~= nil, "the run is a real net")
assert(t.pipe_pressure(2, 1) < 1.0, "and it is empty until something fills it")

-- Unwrench the middle: the run parts in two and gives back a length.
t.drop(p)
t.run_ticks(2)
t.click(p, 3, 3) -- wrench
t.run_ticks(2)
t.click(p, 2, 1)
t.run_seconds(1.5)
assert(t.pipe(2, 1) == 0, "the middle length came up")
assert(t.pipe(1, 1) == DISTRO, "the ends stayed")
assert(t.pipe(3, 1) == DISTRO)
assert(t.count_items("pipe") > 0, "and it is a length you can lay again")
assert(t.ledger_has("PipePulled"), "pulling a line is on the record too")

-- ---------------------------------------------------------------
-- What the plumbing is FOR. A hall and a sealed closet with no door
-- and no shared wall face -- the only thing crossing between them is
-- a pipe run, and it stops one tile short.
--
-- The closet is opened to space and empties, welded shut again, and
-- then an engineer lays the one length that finishes the line. A
-- passive vent at each end is an open hole between run and room, so
-- gas goes where the pressure says. Nothing here can MAKE air: if
-- the closet comes back to life, the hall paid for it.
-- ---------------------------------------------------------------
t.world([==[(
    name: "transfer",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'p': (turf: Plating, fixture: Some(PassiveVent)),
    },
    rows: [
        "##############",
        "#..........#.#",
        "#....p.....#p#",
        "#..........#.#",
        "##############",
    ],
    spawns: [(12, 2)],
    items: [(12, 2, "welder"), (12, 3, "pipe")],
    pipes: [
        (5, 2, 4), (6, 2, 4), (7, 2, 4), (8, 2, 4),
        (9, 2, 4), (10, 2, 4), (11, 2, 4),
    ],
)]==], 7)
local q = t.join()
t.tick()

-- The mapped run is commissioned, unlike the one built above, and it
-- passes UNDER the wall between the two rooms. It stops one tile
-- short: the closet's vent has nothing to draw from yet.
assert(t.pipe_pressure(8, 2) > 90.0, "a mapped line is handed over charged")
assert(t.room_pressure(12, 1) > 90.0, "and both rooms start breathable")
assert(t.turf(11, 2) == "wall", "the line runs under a wall")
assert(t.pipe_pressure(12, 2) == nil, "but stops short of the closet")

-- Take the length of pipe FIRST and park it in the other hand. Loose
-- things do not survive a decompression: what is not in your hands
-- when the hull opens gets dragged wherever the air goes.
t.click(q, 12, 3)
t.run_ticks(2)
t.swap_hands(q)
t.run_ticks(2)

-- Open the closet to space. Nothing feeds it, so it empties.
t.click(q, 12, 2) -- the welder, underfoot
t.fault(12, 1, 6)
t.run_seconds(6)
assert(t.is_breached(12, 1), "the fault opened the closet")
local emptied = t.room_pressure(12, 3)
assert(emptied < 25.0, "the closet emptied: " .. emptied)

-- Seal it again by hand. Now it is a sealed vacuum with a dead vent.
t.click(q, 12, 1)
t.run_seconds(4.5)
assert(not t.is_breached(12, 1), "welded shut")
t.run_seconds(10)
assert(
    t.room_pressure(12, 3) < 25.0,
    "and a sealed vacuum stays a vacuum while the line stops short"
)

-- Finish the plumbing: one length under the vent, and the closet is
-- on the distribution line.
t.swap_hands(q)
t.run_ticks(2)
t.click(q, 12, 2)
t.run_seconds(1.5)
assert(t.pipe(12, 2) == DISTRO, "the last length went down")
assert(t.pipe_pressure(12, 2) ~= nil, "and the vent has a run to draw on")

t.run_seconds(60)
local west_end = t.room_pressure(2, 1)
local east_end = t.room_pressure(12, 3)
assert(east_end > 40.0, "the line repressurised the closet: " .. east_end)
assert(
    west_end < 100.0,
    "and it came out of the hall, not from nowhere: " .. west_end
)
assert(
    math.abs(west_end - east_end) < 20.0,
    "the two settle near each other: " .. west_end .. " vs " .. east_end
)

-- The rooms never touched. Gas crossed because a pipe crosses, and for
-- no other reason.
assert(t.turf(11, 1) == "wall", "the rooms are sealed from each other")
assert(t.turf(11, 3) == "wall")

-- ---------------------------------------------------------------
-- Josh's ruling: "two pipes can carry poison and oxygen and run
-- parallel -- they must NOT intersect. This is precisely where pipes
-- differ from wires, which basically always want to connect."
--
-- Two straight mains, adjacent columns, the SAME piping layer, each
-- aimed north-south (`pipe_facing` dirs 3 = N|S). Pipe joins pipe only
-- where BOTH lengths reach toward each other -- tg's
-- connection_check -- so these two never meet. One of them has a
-- passive vent over it; the other has nothing. Open the room to space
-- and the vented main empties into the vacuum while its neighbour, one
-- tile away on the same layer, stays exactly as charged as it started.
-- ---------------------------------------------------------------
t.world([==[(
    name: "parallel mains",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'p': (turf: Plating, fixture: Some(PassiveVent)),
    },
    rows: [
        "#######",
        "#.....#",
        "#..p..#",
        "#.....#",
        "#######",
    ],
    spawns: [(1, 1)],
    pipes: [
        (3, 1, 4), (3, 2, 4), (3, 3, 4),
        (4, 1, 4), (4, 2, 4), (4, 3, 4),
    ],
    pipe_facing: [
        (3, 1, 4, 3), (3, 2, 4, 3), (3, 3, 4, 3),
        (4, 1, 4, 3), (4, 2, 4, 3), (4, 3, 4, 3),
    ],
)]==], 7)
t.join()
t.tick()

assert(t.pipe_pressure(3, 2) > 90.0, "both mains are handed over charged")
assert(t.pipe_pressure(4, 2) > 90.0)

-- Open the room to space. The vented main drains through its hole.
t.fault(1, 1, 6)
t.run_seconds(6)
assert(t.is_breached(1, 1), "the room is open to space")
t.run_seconds(40)

local vented = t.pipe_pressure(3, 2)
local neighbour = t.pipe_pressure(4, 2)
assert(vented < 25.0, "the vented main emptied: " .. vented)
assert(
    neighbour > 90.0,
    "and its parallel neighbour, one tile away on the same layer, never "
        .. "lost a mole: " .. neighbour
)

-- The control. The identical map with NO facings authored is the old
-- rule: every length reaches every way, the two columns are one slab
-- of pipe, and the vent drains both. That is the topology plain
-- adjacency could not stop expressing, and the reason for the field.
t.world([==[(
    name: "parallel mains, unaimed",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'p': (turf: Plating, fixture: Some(PassiveVent)),
    },
    rows: [
        "#######",
        "#.....#",
        "#..p..#",
        "#.....#",
        "#######",
    ],
    spawns: [(1, 1)],
    pipes: [
        (3, 1, 4), (3, 2, 4), (3, 3, 4),
        (4, 1, 4), (4, 2, 4), (4, 3, 4),
    ],
)]==], 7)
t.join()
t.tick()
t.fault(1, 1, 6)
t.run_seconds(6)
t.run_seconds(40)
assert(
    t.pipe_pressure(4, 2) < 25.0,
    "unaimed, the second column is the same net and drains too: "
        .. t.pipe_pressure(4, 2)
)

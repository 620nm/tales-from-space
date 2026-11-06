local bench = require("@helpers/liquid_bench")
local clock = require("@helpers/clock")
local matter_look = require("@helpers/matter_look")
local ui_controls = require("@helpers/ui_controls")

-- A scupper ends a line: it lets the run down onto its own tile until the
-- two stand level, and nothing comes back. A drain at (1, 1) feeds the run;
-- the scupper hangs on the north wall of the far tile.
local SCUPPER = '(3, 1, "scupper", {"mount": "north", "pipe": "west"})'
local FEED = '(1, 1, "floor_drain", {"pipe": "east"})'

-- Forty litres down the drain. Two ports and a length hold 470 L, and at
-- 0.5 m of head the line levels with the outfall near 16 L, 20 on the tile.
bench.world({
    environment = bench.ONE_G,
    rows = { "#######", "#.#...#", "#######" },
    structures = `(5, 1, "player_spawn"), {FEED}, {SCUPPER}`,
    run = { { x = 2, y = 1 } },
    pools = { { x = 1, y = 1, liters = 40 } },
})
t.run_seconds(100)
local fed = bench.standing(1, 1)
local poured = bench.standing(3, 1) + bench.standing(4, 1) + bench.standing(5, 1)
assert(fed < bench.FILM_L + 1, ("the deck upstream reached its film, %.2f L"):format(fed))
assert(poured > 10, ("the line let down at the outfall, %.2f L"):format(poured))

-- Water at the outfall and an empty line: a two-way mouth would fill it.
bench.world({
    environment = bench.ONE_G,
    rows = { "#####", "#.#.#", "#####" },
    structures = `(1, 1, "player_spawn"), {SCUPPER}`,
    run = { { x = 2, y = 1 } },
    pools = { { x = 3, y = 1, liters = 50 } },
})
t.run_seconds(30)
assert(bench.standing(3, 1) > 49.9, "nothing goes back up a scupper")

-- Weight comes from the deck: the bare ground of the outfall tile has none
-- under this sky, so the same line discharges into a weightless room.
local p = bench.world({
    environment = "environment: (kind: Exact(space), gravity_m_s2: Exact(9.80665)),",
    rows = { "#######", "#.#z..#", "#######" },
    structures = `(5, 1, "player_spawn"), {FEED}, {SCUPPER}`,
    run = { { x = 2, y = 1 } },
    pools = { { x = 1, y = 1, liters = 40 } },
})
t.run_seconds(100)
assert(bench.standing(3, 1) > 5, "a scupper discharges into zero gravity")
local bead = assert(matter_look.parts(p, 3, 1, "puddle")[1], "the water out there is drawn")
assert(bead.weightless, "and it is drawn as beads")

-- No air passes. The drain's pocket shares its air with the run and no
-- further: its 3 m3 against the run's 470 L settles at 86% of what it opened
-- with, and the bare plating past the wall stays open to space.
bench.world({
    environment = bench.ONE_G,
    rows = { "#######", "#.#_   ", "#######" },
    structures = `(1, 1, "player_spawn"), {FEED}, {SCUPPER}`,
    run = { { x = 2, y = 1 } },
    pools = {},
})
local opened = assert(t.room_pressure(1, 1))
t.run_seconds(60)
local settled = assert(t.room_pressure(1, 1))
assert(
    settled > opened * 0.85,
    ("the room keeps its air, %.1f of %.1f kPa"):format(settled, opened)
)
assert((t.room_pressure(3, 1) or 0) < 5, "and the outfall is airless")
t.run_seconds(30)
local later = assert(t.room_pressure(1, 1))
assert(
    math.abs(later - settled) < opened * 0.01,
    ("no bridge bleeds it away, %.1f to %.1f kPa"):format(settled, later)
)

-- Hung by hand from its fitting it finds the run by itself and discharges,
-- and a wrench gives the fitting back.
p = bench.world({
    environment = bench.ONE_G,
    rows = { "#######", "#.#...#", "###...#", "#######" },
    structures = `(3, 1, "player_spawn"), {FEED}`,
    items = '(4, 1, "scupper_fitting"), (3, 2, "wrench")',
    run = { { x = 2, y = 1 } },
    pools = { { x = 1, y = 1, liters = 40 } },
})
t.click(p, 4, 1, assert(t.target_at(p, 4, 1, "scupper_fitting")))
t.run_ticks(2)
ui_controls.build(p, "scupper_fitting", "scupper", 3, 0)
t.run_ticks(clock.deadline_ticks(2.0) + 5)
local hung = t.structure_at(3, 1)
assert(hung and hung.id == "scupper", "hung: " .. table.concat(t.messages(p), " | "))
assert(t.count_items("scupper_fitting") == 0, "the fitting went into the wall")
t.run_seconds(100)
local discharged = 0
for x = 3, 5 do
    discharged += bench.standing(x, 1) + bench.standing(x, 2)
end
assert(discharged > 5, ("a hung scupper joined the run, %.2f L out"):format(discharged))
t.click(p, 3, 2, assert(t.target_at(p, 3, 2, "wrench")))
t.run_ticks(2)
t.click(p, 3, 1, t.target_at(p, 3, 1, "scupper"))
t.run_ticks(clock.deadline_ticks(2.0) + 5)
assert(
    t.structure_at(3, 1) == nil and t.count_items("scupper_fitting") == 1,
    "a wrench brings the fitting back"
)

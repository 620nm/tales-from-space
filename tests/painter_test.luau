-- The pipe painter, and what a stripe of the wrong colour costs.
--
-- tg's `is_connectable` refuses two pipe ends whose paint disagrees
-- unless one of them is omni grey
-- (code/modules/atmospherics/machinery/atmosmachinery.dm:335-354). That
-- makes a paint job plumbing rather than labelling: a technician can cut
-- a live distribution main with a brush, and the line still looks whole.
--
-- So this spec does not assert that a colour was written down. It
-- asserts that the gas stopped arriving.

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

local function heard(p, name)
    for _, s in ipairs(t.sounds(p)) do
        if s == name then
            return true
        end
    end
    return false
end

-- One step, plus the move cooldown (lunatic_core::MOVE_COOLDOWN_TICKS
-- is 4), so two calls in a row are two steps.
local function walk(p, dir)
    t.move(p, dir)
    t.run_ticks(5)
end

-- ---------------------------------------------------------------
-- A supply main painted blue end to end, a canister on a connector
-- port at the west end, and a vent blowing the east end into open
-- space. The bottle pays for everything the vent throws away, which is
-- what makes "the canister stopped draining" a proof that the line
-- stopped carrying.
--
-- The deck is open over the run (pipe is subfloor infrastructure and
-- you cannot paint what you cannot see) except at (6, 1), which is
-- tiled — that one is here to be refused.
-- ---------------------------------------------------------------
t.world([==[(
    name: "painter",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        'o': (turf: Floor),
        'F': (turf: Floor),
        '#': (turf: Wall),
        'c': (turf: Plating, fixture: Some(Canister)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "########  ",
        "#c....F#. ",
        "#aoooog#  ",
        "########  ",
    ],
    spawns: [(1, 2)],
    items: [(1, 2, "pipe_painter")],
    pipes: [
        (2, 1, 4), (3, 1, 4), (4, 1, 4), (5, 1, 4),
        (6, 1, 4), (7, 1, 4),
    ],
    pipe_paint: [
        (2, 1, 4, "#0000FF"), (3, 1, 4, "#0000FF"), (4, 1, 4, "#0000FF"),
        (5, 1, 4, "#0000FF"), (6, 1, 4, "#0000FF"), (7, 1, 4, "#0000FF"),
    ],
    structures: [(1, 1, "connector_port"), (8, 1, "vent")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3), (7, 1, 3), (8, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==], 7)

local p = t.join()
t.tick()

t.click(p, 1, 2, t.target_at(1, 2, "pipe_painter"))
t.run_ticks(2)
assert(t.hands(p).held == "pipe_painter", "painter in hand")

-- Let the bottle, the line and the hole outside find their standoff.
t.run_seconds(10)

-- ---- one colour, one net ----
--
-- Six lengths in one blue line are ONE body of gas, so both ends read
-- the same number to the last decimal: they are literally the same
-- cell. That equality is what the rest of this spec breaks.
local west = t.pipe_pressure(2, 1)
local east = t.pipe_pressure(7, 1)
assert(
    math.abs(west - east) < 0.01,
    "one painted run is one pipenet: " .. west .. " vs " .. east
)

-- And the bottle is paying for the vent at the far end of it.
local opening = t.canister_pressure(1, 1)
t.run_seconds(10)
local spent = opening - t.canister_pressure(1, 1)
assert(spent > 100.0, "the canister feeds the line: " .. spent .. " kPa spent")

-- ---- the dial ----
--
-- tg picks the colour off a list prompt; we have no list, so the dial
-- cycles on the in-hand key the way a length of pipe's layer does.
-- Omni, green, blue, then red — tg's own roster order.
local _ = t.messages(p)
t.use_self(p)
t.use_self(p)
t.use_self(p)
t.run_ticks(2)
assert(said(p, "Pipe painter set to red."), "three clicks along tg's roster")

-- ---- painting nothing is refused, and says so ----
walk(p, "east")
walk(p, "east")
walk(p, "east")
walk(p, "east")
local _ = t.messages(p)
t.click(p, 6, 2) -- open deck, no run under it
t.run_ticks(2)
assert(
    said(p, "There is no pipe under the floor here."),
    "a painter waved at bare deck earns a reason"
)
assert(not t.ledger_has("PipePainted"), "and writes no row")

-- ...and neither is painting through a floor you have not opened.
t.click(p, 6, 1) -- tiled, with the run buried under it
t.run_ticks(2)
assert(
    said(p, "The floor is in the way. Pry the tile up first."),
    "you cannot paint a run you cannot see"
)
assert(not t.ledger_has("PipePainted"), "still no row")
assert(t.pipe_pressure(2, 1) == t.pipe_pressure(7, 1), "and still one net")

-- ---- **the headline**: a brush cuts the main ----
t.click(p, 5, 1)
t.run_ticks(2)
assert(said(p, "You paint the pipe red."), "one length changes colour")
assert(heard(p, "click"), "and the room hears it happen")

local rows = t.ledger_rows("pipe_painted")
assert(#rows == 1, "one act, one row: " .. #rows)
assert(rows[1].at[1] == 5 and rows[1].at[2] == 1, "which tile")
assert(rows[1].layers == 4, "which piping layer")
assert(rows[1].color == "#FF0000", "and which colour, so the record can say")

-- The line is intact. Nothing was cut, nothing was welded, the deck is
-- exactly as it was — and the two ends of it are now two networks.
t.run_seconds(10)
local fed = t.pipe_pressure(2, 1)
local starved = t.pipe_pressure(7, 1)
assert(fed > 90.0, "the bottle's half filled to its setpoint: " .. fed)
assert(starved < 10.0, "and the vent's half emptied into space: " .. starved)

-- The bookkeeping half of the same fact: with nowhere left to send it,
-- the canister has stopped spending. (Measured after the near half has
-- filled, so what is left is the flat line and not the filling.)
local settled = t.canister_pressure(1, 1)
t.run_seconds(10)
local trickle = settled - t.canister_pressure(1, 1)
assert(trickle < 2.0, "a severed main draws nothing: " .. trickle .. " kPa")

-- ---- and paints it back ----
--
-- Blue again. Two nets become one through the same conserving rebuild
-- that split them, the vent's half is fed once more, and the bottle
-- goes back to paying for it.
local _ = t.messages(p)
t.use_self(p) -- red -> orange
t.use_self(p) -- orange -> cyan
t.use_self(p) -- cyan -> dark
t.use_self(p) -- dark -> yellow
t.use_self(p) -- yellow -> brown
t.use_self(p) -- brown -> pink
t.use_self(p) -- pink -> purple
t.use_self(p) -- purple -> violet
t.use_self(p) -- violet -> omni (the roster wraps)
t.use_self(p) -- omni -> green
t.use_self(p) -- green -> blue
t.run_ticks(2)
assert(said(p, "Pipe painter set to blue."), "the roster wraps, twelve long")

t.click(p, 5, 1)
t.run_ticks(2)
assert(said(p, "You paint the pipe blue."), "the stripe comes out")
t.run_seconds(10)

local rejoined_west = t.pipe_pressure(2, 1)
local rejoined_east = t.pipe_pressure(7, 1)
assert(
    math.abs(rejoined_west - rejoined_east) < 0.01,
    "one line again: " .. rejoined_west .. " vs " .. rejoined_east
)

local resumed = t.canister_pressure(1, 1)
t.run_seconds(10)
local paying = resumed - t.canister_pressure(1, 1)
assert(paying > 100.0, "and the bottle is paying for the hole again: " .. paying)

-- Two acts, two rows. The record can name who cut the main and who put
-- it back, which is the whole reason paint earns rows at all.
assert(#t.ledger_rows("pipe_painted") == 2, "both acts on the record")

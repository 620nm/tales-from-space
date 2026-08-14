-- An intact floor tile hides its plumbing, and hiding it means hiding it
-- from tools as well as from eyes.
--
-- tg does this at the turf: `/turf/proc/levelupdate()` sends
-- COMSIG_OBJ_HIDE to everything standing in a covered tile
-- (code/game/turfs/turf.dm:503-506), which drops pipes, disposals and
-- wires to UNDERFLOOR_HIDDEN (code/__DEFINES/turfs.dm:50-54;
-- atmospherics registers for the signal in code/modules/atmospherics/
-- machinery/atmosmachinery.dm:135-145, `var/hide = TRUE` on line 38).
-- The rule is NOT "the tool declines" -- the buried thing is not there
-- to be clicked at all. So the wrench and the wirecutters answer a
-- covered tile with silence: no do_after, no ledger row, and above all
-- no message, because "you can't reach the pipe" would be a free survey
-- of what is buried under a station's floors.
--
-- Laying is the mirror case and speaks: you are placing something you
-- hold onto a floor you can see, so the refusal describes the floor and
-- gives nothing away.

local DISTRO = 4 -- piping layer 3
local BRANCH = 2 -- cable layer 2

local function said(p, want)
    for _, m in ipairs(t.messages(p)) do
        if m:find(want, 1, true) then
            return true
        end
    end
    return false
end

-- (2, 1) is open plating and (2, 2) a finished floor tile; the same run
-- of pipe and the same branch cable pass under both. Every assertion
-- below is that pair answering differently. (2, 3) is a bare covered
-- tile, for the laying half.
t.world([==[(
    name: "subfloor",
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
        "#.o.#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [
        (1, 1, "wrench"),
        (3, 1, "wirecutters"),
        (1, 3, "cable_coil"),
        (3, 3, "crowbar"),
        (1, 2, "pipe"),
        (3, 2, "wrench"),
    ],
    pipes: [(2, 1, 4), (2, 2, 4)],
    cables: [(2, 1, 2), (2, 2, 2)],
)]==], 7)

local p = t.join()
t.tick()
assert(t.turf(2, 1) == "plating", "one tile is open")
assert(t.turf(2, 2) == "floor", "and its neighbour is tiled over")
assert(t.pipe(2, 2) == DISTRO, "the run passes under the tiled one")
assert(t.cable_at(2, 2) == BRANCH, "and so does the cable")

-- ---------------------------------------------------------------
-- The wrench. Buried pipe under a tile is not wrenchable.
-- ---------------------------------------------------------------
t.click(p, 1, 1) -- pick up the wrench
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "wrench in hand")
local _ = t.messages(p)

t.click(p, 2, 2)
t.run_seconds(1.5)
assert(t.pipe(2, 2) == DISTRO, "the buried run is untouched")
assert(not said(p, "unwrenching"), "and the wrench never started on it")
assert(#t.ledger_rows("PipePulled") == 0, "nothing to put on the record")
assert(t.count_items("pipe") == 1, "no length came up (only the mapped one)")

-- The same click, one tile north where the deck is open, works. This is
-- what makes the silence above a rule about the floor and not a broken
-- hook.
t.click(p, 2, 1)
t.run_seconds(1.5)
assert(t.pipe(2, 1) == 0, "open plating gives the length up")
assert(#t.ledger_rows("PipePulled") == 1, "and that one IS on the record")

-- ---------------------------------------------------------------
-- The wirecutters. Same rule, sabotage side.
-- ---------------------------------------------------------------
t.drop(p)
t.run_ticks(2)
t.click(p, 3, 1)
t.run_ticks(2)
assert(t.hands(p).held == "wirecutters", "cutters in hand")
_ = t.messages(p)

t.click(p, 2, 2)
t.run_seconds(1.5)
assert(t.cable_at(2, 2) == BRANCH, "the buried cable is untouched")
assert(not said(p, "snipping"), "and the cutters never bit")
assert(#t.ledger_rows("CableCut") == 0, "no cut to attribute")

t.click(p, 2, 1)
t.run_seconds(1.5)
assert(t.cable_at(2, 1) == 0, "open plating cuts fine")
assert(#t.ledger_rows("CableCut") == 1, "and that cut is attributed")

-- ---------------------------------------------------------------
-- Laying, both trades: refused over a tile, and it says why.
-- ---------------------------------------------------------------
t.drop(p)
t.run_ticks(2)
t.click(p, 1, 3) -- the coil
t.run_ticks(2)
_ = t.messages(p)
t.click(p, 2, 3)
t.run_seconds(1.5)
assert(t.cable_at(2, 3) == 0, "no cable goes down over a finished floor")
assert(#t.ledger_rows("CableLaid") == 0, "nothing laid, nothing recorded")
assert(
    said(p, "The floor is in the way. Pry the tile up first."),
    "and the refusal says what to do about it"
)

t.drop(p)
t.run_ticks(2)
t.click(p, 1, 2) -- the length of pipe
t.run_ticks(2)
_ = t.messages(p)
t.click(p, 2, 3)
t.run_seconds(1.5)
assert(t.pipe(2, 3) == 0, "no length goes down over a finished floor either")
assert(
    said(p, "The floor is in the way. Pry the tile up first."),
    "same instruction, same words"
)

-- ---------------------------------------------------------------
-- Pry the tile up and the plumbing is ordinary work again.
-- ---------------------------------------------------------------
t.drop(p)
t.run_ticks(2)
t.click(p, 3, 3) -- the crowbar
t.run_ticks(2)
t.click(p, 2, 2)
t.run_ticks(2)
assert(t.turf(2, 2) == "plating", "the tile came up")

t.drop(p)
t.run_ticks(2)
t.click(p, 3, 2) -- the spare wrench, kept clear of the pile at our feet
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "wrench in hand again")

t.click(p, 2, 2)
t.run_seconds(1.5)
assert(t.pipe(2, 2) == 0, "the same click that did nothing now pulls the run")
assert(#t.ledger_rows("PipePulled") == 2, "and the second pull is recorded")

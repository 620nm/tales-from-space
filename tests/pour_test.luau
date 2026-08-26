-- Pouring: a beaker tipped into another vessel moves exactly what it
-- says, in the proportions it was holding, and stops where the GLASS
-- runs out. Capacity is geometry (docs/MATTER.md 5), so "the brim" is
-- millilitres of shell against millilitres of liquid and never a count
-- of moles.
--
-- What happens to the share that would not fit is the POUR's, and it is
-- the reason `sim.matter.pour` is a word of its own rather than an
-- argument to `sim.matter.transfer` (docs/LUAU-API.md 8.2): tipping a
-- jug into a full glass runs down the outside of it. The source gives
-- up the whole gesture and the deck under the far vessel takes the
-- rest, as its own `spilled` row. A generic transfer would have kept
-- it; a pour is not a generic transfer.
t.world([==[(
    name: "chem bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "######",
        "#....#",
        "######",
    ],
    spawns: [(2, 1)],
    items: [
        (1, 1, "beaker.libital"),
        (2, 1, "beaker.libital"),
        (3, 1, "beaker"),
        (4, 1, "beaker.libital"),
    ],
)]==], 0)

local p = t.join()
t.tick()

local a = t.target_at(1, 1, "beaker.libital")
local b = t.target_at(2, 1, "beaker.libital")
local c = t.target_at(3, 1, "beaker")
local e = t.target_at(4, 1, "beaker.libital")

local function total(handle)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    local n = 0
    for _, moles in pairs(contents) do
        n = n + moles
    end
    return n
end

local function close(got, want, what)
    assert(math.abs(got - want) < 1e-9, ("%s: wanted %g, got %g"):format(what, want, got))
end

local function near(got, want, tol, what)
    assert(math.abs(got - want) < tol, ("%s: wanted %g, got %g"):format(what, want, got))
end

-- The brim is a VOLUME (docs/MATTER.md 5). Water is 18.015 mL to the
-- mole and libital 180, a beaker is fifty millilitres of glass, and
-- what a beaker.libital ships with -- 0.20 water and 0.15 libital --
-- is 30.60 of those fifty. Everything the trims below come to is those
-- four numbers and nothing else.
local WATER_ML, LIBITAL_ML, GLASS_ML = 18.015, 180.0, 50.0
local function litres_of(water, libital)
    return water * WATER_ML + libital * LIBITAL_ML
end
-- The share of a 0.25 mol parcel of that mix which fits in what a full
-- beaker.libital leaves free.
local FIT = 0.25
    * ((GLASS_ML - litres_of(0.20, 0.15)) / litres_of(0.25 * 4 / 7, 0.25 * 3 / 7))

-- An empty beaker off the shelf is still a vessel: it holds nothing and
-- has fifty millilitres of room (volume_ml on the prototype).
close(total(c), 0, "the bare beaker ships empty")

-- Pick the first beaker up and pour it into the empty one.
t.click(p, 1, 1, a)
t.tick()
local before = total(a)
close(before, 0.35, "the libital beaker ships full")

t.click(p, 3, 1, c)
t.tick()
close(total(c), 0.25, "one gesture pours 0.25 mol")
close(total(a), before - 0.25, "and the source is down by exactly that")
-- Proportional, like tg's trans_to: the mix that arrives is the mix
-- that left, in the same ratio.
local poured = t.contents(c)
close(poured.water, 0.20 * (0.25 / 0.35), "water went in proportion")
close(poured.libital, 0.15 * (0.25 / 0.35), "libital went in proportion")

-- Empty the rest into the second beaker, then fill IT from the one we
-- just poured: the bench is now one nearly-full vessel.
t.drop(p)
t.tick()
t.click(p, 3, 1, c) -- pick the poured-into beaker back up
t.tick()
t.click(p, 2, 1, b)
t.tick()
-- b was already thirty of its fifty millilitres full, so the gesture
-- trims: what goes in is the share of the parcel the free volume has
-- room for...
near(total(b), 0.35 + FIT, 1e-4, "0.35 plus what the glass had room for")
-- ...and the rest goes down the outside. The source is EMPTY: it gave
-- up the whole 0.25 it was asked for, and the deck under b holds the
-- difference on its own row.
close(total(c), 0, "the source gave up the whole gesture")
local over = t.ledger_rows("spilled")
assert(#over == 1, ("one overflow on the record, got %d"):format(#over))
near(over[1].moles, 0.25 - FIT, 1e-6, "the row names what would not fit")
assert(over[1].at[1] == 2 and over[1].at[2] == 1, "on the tile the far beaker stands on")

-- b is brim-full now: fifty millilitres of liquid in fifty millilitres
-- of glass. Pouring a whole beaker into it moves nothing at all — and
-- nothing overflows either, because a pour that fits NOTHING is a
-- refusal rather than a spill: everything drawn goes straight back.
t.drop(p)
t.tick()
t.move(p, "east")
t.tick()
t.click(p, 4, 1, e)
t.tick()
close(total(e), 0.35, "the third beaker is untouched so far")

t.click(p, 2, 1, b)
t.tick()
near(total(b), 0.35 + FIT, 1e-4, "full is full")
close(total(e), 0.35, "and nothing left the source")

-- ...and it stays that way however many times you tip it.
t.click(p, 2, 1, b)
t.tick()
near(total(b), 0.35 + FIT, 1e-4, "still exactly full")
close(total(e), 0.35, "nothing left the source")
-- Two pours happened and two are on the record; a refusal is not a
-- transfer and writes no row.
local rows = t.ledger_rows("poured")
assert(#rows == 2, ("two pours are on the record, got %d"):format(#rows))
close(rows[1].moles, 0.25, "the first row names what moved")
near(rows[2].moles, FIT, 1e-4, "and the second names the trimmed amount")
-- And the overflow is still the ONE row it always was: the two refused
-- pours above spilled nothing, because nothing was drawn.
assert(#t.ledger_rows("spilled") == 1, "a refused pour overflows nothing")

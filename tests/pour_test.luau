-- Pouring: a beaker tipped into another vessel moves exactly what it
-- says, in the proportions it was holding, and stops at the brim of the
-- thing being filled — the remainder stays where it was.
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
        (1, 1, "beaker_libital"),
        (2, 1, "beaker_libital"),
        (3, 1, "beaker"),
        (4, 1, "beaker_libital"),
    ],
)]==], 0)

local p = t.join()
t.tick()

local a = t.target_at(1, 1, "beaker_libital")
local b = t.target_at(2, 1, "beaker_libital")
local c = t.target_at(3, 1, "beaker")
local e = t.target_at(4, 1, "beaker_libital")

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

-- An empty beaker off the shelf is still a vessel: it holds nothing and
-- has room for a great deal (capacity_mol on the prototype).
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
close(total(b), 0.60, "0.35 + a 0.25 pour")
close(total(c), 0, "and the source is empty")

-- Now pour a full beaker into it: only 0.10 mol will fit, and the rest
-- stays in the hand that poured it.
t.drop(p)
t.tick()
t.move(p, "east")
t.tick()
t.click(p, 4, 1, e)
t.tick()
close(total(e), 0.35, "the third beaker is untouched so far")

t.click(p, 2, 1, b)
t.tick()
close(total(b), 0.70, "the target trimmed at its brim")
close(total(e), 0.25, "and the source kept the remainder")

-- Full is full: the gesture is refused and nothing moves.
t.click(p, 2, 1, b)
t.tick()
close(total(b), 0.70, "still exactly full")
close(total(e), 0.25, "nothing left the source")
-- Three transfers happened and three are on the record; the refusal is
-- not a transfer and writes no row.
local rows = t.ledger_rows("poured")
assert(#rows == 3, ("three pours are on the record, got %d"):format(#rows))
close(rows[1].moles, 0.25, "the first row names what moved")
close(rows[3].moles, 0.10, "and the last names the trimmed amount")

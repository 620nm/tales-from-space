-- The small glass: a dropper, a test tube and a bottle, each holding
-- what tg says it holds and each moving what tg says it moves.
--
-- The interesting one is the dropper. Its whole reason to exist is that
-- it moves LESS than a beaker can: five units of capacity and one unit
-- a squeeze, so a beaker tipped into it fills it and stops, and a
-- squeeze out of it is a tenth of what a beaker's gesture moves. A
-- vessel that could not be overfilled, or could not be emptied slowly,
-- would pass every assertion about capacity alone.
t.world([==[(
    name: "chem bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#######",
        "#.....#",
        "#.....#",
        "#######",
    ],
    spawns: [(1, 1)],
    items: [
        (2, 1, "beaker.libital"),
        (3, 1, "dropper"),
        (4, 1, "bottle"),
        (5, 1, "test_tube"),
    ],
)]==], 0)

local U = 0.025

local p = t.join()
t.tick()

local beaker = t.target_at(2, 1, "beaker.libital")
local dropper = t.target_at(3, 1, "dropper")
local bottle = t.target_at(4, 1, "bottle")
local tube = t.target_at(5, 1, "test_tube")

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

-- All three ship EMPTY and all three are vessels: `t.contents` answers
-- a table rather than nil for a thing that holds nothing yet.
close(total(dropper), 0, "the dropper ships empty")
close(total(bottle), 0, "the bottle ships empty")
close(total(tube), 0, "the tube ships empty")

-- A beaker tipped into the dropper. The gesture says 10 u and the
-- dropper is five millilitres of glass, so it trims at the brim (tg's
-- `trans_to`, holder.dm:472/480) and what will not fit runs down the
-- outside onto the deck — a POUR's overflow policy, which is the whole
-- of the difference between `sim.matter.pour` and the generic
-- `sim.matter.transfer`.
--
-- The brim is a VOLUME (docs/MATTER.md 5). A mole of the beaker's mix
-- is four sevenths water at 18.015 mL and three sevenths libital at
-- 180 mL -- 87.43 mL to the mole -- so five millilitres is 0.05718 of
-- one.
t.click(p, 2, 1, beaker)
t.tick()
close(total(beaker), 0.35, "the libital beaker ships full")

t.move(p, "east")
t.tick()
t.click(p, 3, 1, dropper)
t.tick()
-- Five millilitres of glass over 87.43 mL to the mole of that mix.
local FIT = 5e-6 / ((4 / 7) * 18.015e-6 + (3 / 7) * 180e-6)
close(total(dropper), FIT, "the dropper fills to its brim and no further")
-- The beaker gave up the WHOLE gesture: what the dropper could not
-- take ran down the outside of it onto the deck, which is what makes
-- `sim.matter.pour` a different word from `sim.matter.transfer`
-- (docs/LUAU-API.md 8.2).
close(total(beaker), 0.35 - 10 * U, "and the beaker gave up the whole gesture")
local over = t.ledger_rows("spilled")
assert(#over == 1, ("one overflow on the record, got %d"):format(#over))
assert(
    math.abs(over[1].moles - (10 * U - FIT)) < 1e-6,
    ("the row names what would not fit, got %g"):format(over[1].moles)
)

-- Now the squeeze: ONE unit out of the dropper, the bottom of tg's
-- `possible_transfer_amounts` (dropper.dm:9) and a tenth of what the
-- beaker's gesture moved above.
t.drop(p)
t.tick()
t.click(p, 3, 1, dropper)
t.tick()
t.move(p, "east")
t.tick()
t.click(p, 4, 1, bottle)
t.tick()
close(total(bottle), 1 * U, "one unit a squeeze")
close(total(dropper), FIT - 1 * U, "and the dropper is down exactly one")

-- Proportional, like every other transfer here: what arrives is what
-- left, in the ratio it was standing in.
local drops = t.contents(bottle)
close(drops.water, (0.20 / 0.35) * (1 * U), "water went in proportion")
close(drops.libital, (0.15 / 0.35) * (1 * U), "libital went in proportion")

-- And the deck: a dropper tipped out empties like anything else, onto
-- a clear tile so the gesture cannot be a pickup instead.
t.click(p, 3, 2)
t.tick()
close(total(dropper), 0, "the dropper tips out onto the deck")

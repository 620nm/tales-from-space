-- Variants: `beaker.libital` is a beaker, and it is not the beaker.
--
-- A named preconfiguration is a prototype derived from its base
-- (docs/CONTENT-SCHEMA.md section 1.1a), not a copy of its file. Three
-- claims, all of them things a player could cause:
--
--   1. It is a real id. A map places it, `t.target_at` finds it by the
--      dotted spelling, and a look reports its own name and its own
--      charge -- which the empty beaker beside it does not have.
--   2. The base's gestures are its gestures. `lib/vessel.luau` attaches
--      pour, sip and spill to `beaker` and to nothing else; a pour out
--      of the variant into the bare one still works, because a handler
--      bound to the base governs everything derived from it.
--   3. What it IS stays its own. The thing in your hand reports
--      `beaker.libital`, never `beaker`.
t.world([==[(
    name: "variant bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1)],
    items: [(1, 1, "beaker.libital"), (2, 1, "beaker")],
)]==], 0)

local p = t.join()
t.tick()

-- 1. THE DOTTED ID IS AN ID.
local mixed = t.target_at(1, 1, "beaker.libital")
local empty = t.target_at(2, 1, "beaker")
assert(mixed ~= nil, "the map placed the variant by its own id")
assert(empty ~= nil, "and the bare beaker beside it")
assert(mixed ~= empty, "they are two different things on two tiles")

local function total(handle)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    local n = 0
    for _, moles in pairs(contents) do
        n = n + moles
    end
    return n
end

-- The variant arrives holding what its `contents` said; the base
-- arrives empty, because the base said nothing.
assert(math.abs(total(mixed) - 0.35) < 1e-9, ("the variant is charged: %g"):format(total(mixed)))
assert(math.abs(total(empty)) < 1e-9, ("the base ships empty: %g"):format(total(empty)))

-- The same fact through the vessel reader, which is what a machine
-- and a panel see.
local reading = t.vessel(mixed)
assert(reading ~= nil, "a vessel reads")
assert(reading.contents["libital"] ~= nil, "and the drug is one of the things in it")
assert(t.vessel(empty).contents["libital"] == nil, "the bare one carries none of it")

-- Its own name and its own prose, both the variant's.
local look = t.examine(p, 1, 1, mixed)
assert(look ~= nil, "a vessel in view answers")
assert(look.title == "beaker (libital)", "the heading is the variant's name: " .. look.title)
assert(look.sprite == "beaker", "wearing the picture it inherited")
local bare = t.examine(p, 2, 1, empty)
assert(bare.title == "beaker", "and the base is still the base: " .. bare.title)
assert(
    bare.lines[1] == look.lines[1],
    "prose the variant did not override is the base's own"
)

-- 2. THE BASE'S GESTURES ARE ITS GESTURES.
--
-- `vessel.attach` bound one behaviour, to `beaker`. Picking the variant
-- up and clicking the empty beaker with it is the pour that handler
-- implements: if a variant did not route to its base, this click would
-- reach nothing at all.
t.click(p, 1, 1, mixed) -- pick it up

-- 3. AND IT IS STILL ITSELF IN HAND.
assert(t.hands(p).held == "beaker.libital", "what is in hand is the variant, not the base")

t.tick()
local before = total(empty)
t.click(p, 2, 1, empty) -- pour into the bare beaker
t.tick()
assert(total(empty) > before, ("the pour landed: %g -> %g"):format(before, total(empty)))
assert(total(mixed) < 0.35, "and came out of the variant")

local rows = t.ledger_rows("poured")
assert(#rows >= 1, "the pour is on the record like any other")

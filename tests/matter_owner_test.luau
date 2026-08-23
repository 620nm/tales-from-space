-- One transfer, three far ends: a beaker poured into another vessel,
-- drunk from, and tipped onto the deck are the SAME call in the file
-- that does them (`ctx.matter_transfer`, docs/LUAU-API.md section 8.2),
-- differing only in which owner is named.
--
-- What makes this worth a spec rather than a comment is the second
-- claim underneath it: collapsing the three spellings changed nothing a
-- player or an admin can see. The amounts are the amounts they were,
-- the refusals are the refusals they were, and the rows the shift
-- ledger gets are still `poured`, `drank` and `spilled` — because the
-- row follows WHAT MOVED WHERE rather than which binding asked, so an
-- admin reading a shift back cannot tell that content was rewritten.
--
-- The third gesture is the one that had no general form before: the far
-- end of a transfer is the ROOM over a tile (`ctx.cell(x, y)`), which
-- is a body of matter like any other. What lands there is ordinary
-- matter from the instant it exists — so the last leg of this spec
-- waits, and watches the puddle dry into the air above it.
t.world([==[(
    name: "owner bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "######",
        "#....#",
        "#....#",
        "######",
    ],
    spawns: [(2, 1)],
    items: [
        (1, 1, "beaker_libital"),
        (3, 1, "beaker"),
    ],
)]==], 0)

local p = t.join()
t.tick()

local full = t.target_at(1, 1, "beaker_libital")
local empty = t.target_at(3, 1, "beaker")

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

close(total(empty), 0, "the bare beaker ships empty")

-- ---- owner: another vessel --------------------------------------------
t.click(p, 1, 1, full) -- pick the full one up
t.tick()
close(total(full), 0.35, "the libital beaker ships full")

t.click(p, 3, 1, empty)
t.tick()
close(total(empty), 0.25, "a transfer into a vessel moves what it says")
close(total(full), 0.10, "and the source is down by exactly that")

local poured = t.ledger_rows("poured")
assert(#poured == 1, ("one pour on the record, got %d"):format(#poured))
close(poured[1].moles, 0.25, "the row names what moved")
assert(poured[1].actor.kind == "script", "attributed to the file that asked")

-- ---- owner: a body's blood --------------------------------------------
-- The same call with the far end named as a MOB: liquid out of a held
-- vessel into a bloodstream is drinking, and the ledger says so without
-- the content file ever spelling the word.
t.click(p, 2, 1)
t.tick()
close(total(full), 0.05, "a swig takes 0.05 mol")
local drank = t.ledger_rows("drank")
assert(#drank == 1, ("one swig on the record, got %d"):format(#drank))
close(drank[1].moles, 0.05, "and the row names the mouthful")

-- ---- owner: the room over a tile --------------------------------------
-- The far end nothing but a spill could name before. `ctx.cell(x, y)` is
-- a body of matter like any other, so "tip it out" is the one transfer
-- with a tile on the end of it.
local function vapour(key)
    local gases = t.room_gas(2, 2)
    return (gases and gases[key]) or 0
end
local gas_before = vapour("water")

t.click(p, 2, 2)
t.tick()
close(total(full), 0, "the beaker is empty")

local spilled = t.ledger_rows("spilled")
assert(#spilled == 1, ("one spill on the record, got %d"):format(#spilled))
close(spilled[1].moles, 0.05, "the row names the remainder")
assert(spilled[1].at[1] == 2 and spilled[1].at[2] == 2, "and the tile it landed on")

-- Nothing gasified on the way down: what a transfer deposits in a cell
-- arrives in the phase it left in.
close(vapour("water"), gas_before, "the air over the tile is unchanged")

-- ...and then it behaves like matter, because it IS matter: the water
-- in the puddle evaporates into the room until the air above it is
-- saturated (docs/MATTER.md section 5). A deposit that had gone into
-- some second system beside the air could not do this.
t.run_seconds(120)
local dried = vapour("water")
assert(dried > gas_before, "the puddle is drying into the room: " .. dried .. " mol")

-- ---- and the refusals are still native --------------------------------
-- An empty vessel has nothing to give, whichever owner is on the far
-- end, and a refusal writes no second row.
t.click(p, 3, 1, empty)
t.tick()
t.click(p, 2, 2)
t.tick()
assert(#t.ledger_rows("spilled") == 1, "the empty beaker spilled nothing")

-- Undressing somebody else, and what it unblocks.
--
-- The whole point of the feature is the last two assertions: surgery
-- refuses a covered zone (tests/surgery_refusal_test.luau proves the
-- refusal), and until now there was no way to uncover one on a body
-- that was not your own.  So this spec runs the loop end to end -- drag
-- the cadaver onto yourself, read the wardrobe, take the jumpsuit off,
-- watch it land on the deck -- and then puts a scalpel to the chest
-- that was covered a moment ago.
--
-- tg: /datum/element/strippable's mouse-drop hook and its strip menu
-- (code/datums/elements/strippable.dm:36-63, :355-390).

local ARENA = [==[(
    name: "ward",
    legend: { ' ': (turf: Space), '.': (turf: Floor), '#': (turf: Wall) },
    rows: [ "#####", "#...#", "#####" ],
    spawns: [(1, 1), (2, 1)],
    items: [ (1, 1, "scalpel") ],
)]==]

t.world(ARENA, 0)
local crewman = t.join()
local cadaver = t.join()
t.run_ticks(3)

local AX, AY = 1, 1 -- the crewman
local CX, CY = 2, 1 -- the body being worked on
local cid = t.body_id(cadaver)
local aid = t.body_id(crewman)

local function said(who, needle)
    return (" " .. table.concat(t.messages(who), " || ") .. " "):find(needle, 1, true) ~= nil
end
local function has(list, id)
    for _, v in ipairs(list) do if v == id then return true end end
    return false
end
local function row(panel, label)
    for _, r in ipairs(panel.readouts or {}) do
        if r.label == label then return r end
    end
    for _, r in ipairs(panel.toggles or {}) do
        if r.option == label then return r end
    end
    return nil
end

-- ---- the drag opens the wardrobe --------------------------------------
assert(t.worn(cadaver).uniform ~= nil, "roundstart puts them in a jumpsuit")
t.drag(crewman, CX, CY, cid, AX, AY, aid)
t.run_ticks(2)
local panel = t.ui(crewman)
assert(panel ~= nil, "dragging a body onto yourself opens its wearables")
assert(panel.presentation == "choices", "a slot grid is a list of choices")
local uniform = row(panel, "uniform")
assert(uniform ~= nil and uniform.field == "strip", "the filled slot has a strip button")
-- An empty slot the crewman is not holding anything for is a row that
-- says so, and carries no button at all.
assert(row(panel, "Suit") ~= nil, "the empty suit slot is still named")

-- ---- the strip: parked, then landed -----------------------------------
t.ui_act(crewman, "toggle", '{"field":"strip","option":"uniform"}')
t.run_ticks(2)
assert(#t.ledger_rows("DoAfterStarted") > 0, "the strip parked")
assert(t.worn(cadaver).uniform ~= nil, "and nothing has come off yet")
assert(said(cadaver, "starts taking your"), "the victim is told it is happening")

-- The jumpsuit declares no `strip_secs`, so it takes the engine default
-- of four seconds (tg's own `strip_delay` default, items.dm:164).
t.run_ticks(85)
assert(t.worn(cadaver).uniform == nil, "the slot is empty")
assert(has(t.items_at(CX, CY), "uniform_grey"), "and it landed at their feet")
assert(#t.ledger_rows("Stripped") > 0, "the record names both people")
assert(said(crewman, "You take"), "and the crewman is told what they did")

-- ---- what it was FOR --------------------------------------------------
-- The same click that said "covered" in tests/surgery_refusal_test.luau
-- now finds a bare chest and starts cutting.
t.rest(cadaver, true)
t.run_ticks(2)
t.click(crewman, 1, 1, t.target_at(1, 1, "scalpel"))
t.run_ticks(2)
local parked = #t.ledger_rows("DoAfterStarted")
t.click(crewman, CX, CY, cid)
t.run_ticks(2)
assert(not said(crewman, "covered"), "nothing is in the way any more")
assert(#t.ledger_rows("DoAfterStarted") > parked, "the incision parked")

-- ---- and back the other way ------------------------------------------
-- tg's strip menu fills an empty slot as readily as it empties a full
-- one, at the garment's `equip_delay_other` (strippable.dm:242).  The
-- scalpel goes down first, which ends the incision we just parked --
-- that is the two-party guard doing its job and not this spec's
-- subject.
t.drop(crewman)
t.run_ticks(2)
t.click(crewman, CX, CY, t.target_at(CX, CY, "uniform_grey"))
t.run_ticks(2)
assert(t.hands(crewman).held == "uniform_grey", "the jumpsuit is back in hand")

t.drag(crewman, CX, CY, cid, AX, AY, aid)
t.run_ticks(2)
local refill = row(t.ui(crewman), "uniform")
assert(refill ~= nil and refill.field == "dress", "the empty slot offers to be filled")

local dressed = #t.ledger_rows("Dressed")
t.ui_act(crewman, "toggle", '{"field":"dress","option":"uniform"}')
t.run_ticks(2)
assert(t.worn(cadaver).uniform == nil, "still in hand while the do_after runs")
t.run_ticks(85)
assert(t.worn(cadaver).uniform ~= nil, "and worn again at the end of it")
assert(t.hands(crewman).held == nil, "out of the hand that carried it")
assert(#t.ledger_rows("Dressed") > dressed, "the record names who dressed whom")
assert(said(cadaver, "puts"), "and the wearer is told it happened to them")

print("strip: drag opens the wardrobe, the garment hits the deck, surgery follows; and dressing puts it back")

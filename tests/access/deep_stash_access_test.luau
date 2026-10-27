-- A body carrying a stash nested past the inventory read's 32-level bound still
-- derives its access from hands, the worn ID and card slots alone: no stale
-- row, the engineering leaf refuses it, and a card in hand then admits it.
local access_bench = require("@helpers/access_bench")

local LEAF = 5
local DEPTH = 34 -- toolboxes in the chain, past the 32-level bound

local floor_items = {}
for _ = 1, DEPTH do
    table.insert(floor_items, "(3, 1, \"toolbox\")")
end
access_bench.world(
    "deep stash",
    access_bench.spawn("assistant", 3) .. ", (5, 1, \"airlock.engineering\")",
    table.concat(floor_items, ", ") .. ", (4, 1, \"id_engineering\")"
)
local courier = t.join("assistant")
t.run_seconds(1.0)

local function pick_toolbox()
    t.click(courier, 3, 1, assert(t.target_at(courier, 3, 1, "toolbox")))
    t.run_ticks(2)
end

-- Each pass stores the chain so far inside one more toolbox, held in a hand.
pick_toolbox()
for _ = 2, DEPTH do
    local hands = t.hands(courier)
    if hands[hands.active] ~= nil then
        t.swap_hands(courier)
        t.run_ticks(1)
    end
    pick_toolbox()
    t.swap_hands(courier)
    t.run_ticks(1)
    t.use_on_other(courier)
    t.run_ticks(2)
end
assert(#t.items_at(3, 1) == 0, "every toolbox went into the chain")
local hands = t.hands(courier)
assert(hands[1] == "toolbox" or hands[2] == "toolbox", "the chain's outermost toolbox is in hand")
assert(t.worn(courier).id == "id_assistant", "the assistant still wears only its own ID")

assert(#t.ledger_rows("held_set_stale") == 0, "the deep stash does not stale the body's access")
local denied = #t.ledger_rows("door_denied")
access_bench.bump(courier, LEAF)
assert(not assert(t.door_at(LEAF, 1)).open, "no card, so the engineering leaf refuses the body")
assert(#t.ledger_rows("door_denied") > denied, "and the refusal is on the record")

t.click(courier, 4, 1, assert(t.target_at(courier, 4, 1, "id_engineering")))
t.run_ticks(2)
access_bench.bump(courier, LEAF)
assert(assert(t.door_at(LEAF, 1)).open, "an engineering card in hand admits the body")
assert(#t.ledger_rows("held_set_stale") == 0, "and the body's access never went stale")

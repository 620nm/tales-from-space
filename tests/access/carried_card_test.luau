-- A card opens a leaf while the body wears it or holds it in either hand. A card
-- stored in the worn backpack grants nothing. The card fitted into a held
-- laptop is carried_card_slot_test.luau's case.
local access_bench = require("@helpers/access_bench")

local LEAF = 5
local ENGINEERING_LEAF = "(5, 1, \"airlock.engineering\")"

local function denials(): number
    return #t.ledger_rows("door_denied")
end

-- ---- worn: the engineering card on the engineer opens the leaf; the
-- assistant's own card does not.
access_bench.world(
    "carried card worn",
    access_bench.spawn("assistant", 3) .. ", " .. access_bench.spawn("engineer", 7) .. ", " .. ENGINEERING_LEAF,
    ""
)
local assistant = t.join("assistant")
local engineer = t.join("engineer")
t.run_seconds(1.0)
assert(t.worn(engineer).id == "id_engineering", "the engineer wears the engineering ID")
assert(t.worn(assistant).id == "id_assistant", "the assistant wears the assistant ID")

local refused = denials()
access_bench.bump(assistant, LEAF)
assert(not assert(t.door_at(LEAF, 1)).open, "an assistant's worn card does not open the engineering leaf")
assert(denials() > refused, "and the refusal is on the record")

access_bench.bump(engineer, LEAF)
assert(assert(t.door_at(LEAF, 1)).open, "the worn engineering card opens the leaf on a bump")

-- ---- held: an engineering card picked up from the floor admits; dropped
-- on the same tile, the very next bump is refused.
access_bench.world("carried card held", access_bench.spawn("assistant", 3) .. ", " .. ENGINEERING_LEAF, "(3, 1, \"id_engineering\")")
local carrier = t.join("assistant")
t.run_seconds(1.0)
t.click(carrier, 3, 1, assert(t.target_at(carrier, 3, 1, "id_engineering")))
t.run_ticks(2)
assert(t.hands(carrier).held == "id_engineering", "the engineering card is in hand")

access_bench.bump(carrier, LEAF)
assert(assert(t.door_at(LEAF, 1)).open, "a held engineering card opens the leaf")
access_bench.wait_until_shut(LEAF)

t.drop(carrier)
t.run_ticks(2)
assert(t.hands(carrier).held == nil, "the card now lies on the floor")
local before_drop_bump = denials()
access_bench.bump(carrier, LEAF)
assert(not assert(t.door_at(LEAF, 1)).open, "the very next bump after the drop is refused")
assert(denials() > before_drop_bump, "and that refusal is on the record")

-- ---- stored: the same card inside the backpack the body wears is no key.
access_bench.world("carried card stored", access_bench.spawn("assistant", 3) .. ", " .. ENGINEERING_LEAF, "(3, 1, \"id_engineering\")")
local packed = t.join("assistant")
t.run_seconds(1.0)
assert(t.worn(packed).back == "backpack", "the assistant wears a backpack")
t.click(packed, 3, 1, assert(t.target_at(packed, 3, 1, "id_engineering")))
t.run_ticks(2)
t.interact_item(packed, { Equipment = { slot = "back" } })
t.run_ticks(2)
assert(table.find(t.stored(packed, "back"), "id_engineering") ~= nil, "the card is inside the backpack")

local stored_refusals = denials()
access_bench.bump(packed, LEAF)
assert(not assert(t.door_at(LEAF, 1)).open, "a card in the worn backpack opens nothing")
assert(denials() > stored_refusals, "and that refusal is on the record")

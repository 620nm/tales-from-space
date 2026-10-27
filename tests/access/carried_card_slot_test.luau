-- A card fitted into the card slot of a carrier the body holds counts, one
-- level down: an engineering card slotted into a laptop on the floor, then the
-- laptop picked up, admits the body at the engineering leaf.
local access_bench = require("@helpers/access_bench")

local LEAF = 5

access_bench.world(
    "carried card slot",
    access_bench.spawn("assistant", 3) .. ", (5, 1, \"airlock.engineering\")",
    "(3, 1, \"id_engineering\"), (3, 1, \"laptop\")"
)
local courier = t.join("assistant")
t.run_seconds(1.0)
t.click(courier, 3, 1, assert(t.target_at(courier, 3, 1, "id_engineering")))
t.run_ticks(2)
t.click(courier, 3, 1, assert(t.target_at(courier, 3, 1, "laptop")))
t.run_ticks(2)
assert(t.hands(courier).held == nil, "the card went into the laptop's card slot")

t.click(courier, 3, 1, assert(t.target_at(courier, 3, 1, "laptop")))
t.run_ticks(2)
assert(t.hands(courier).held == "laptop", "the laptop is in hand")
access_bench.bump(courier, LEAF)
assert(assert(t.door_at(LEAF, 1)).open, "the card inside the held laptop opens the leaf")

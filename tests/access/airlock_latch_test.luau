-- A bolt holds a leaf shut whatever the card says, and the bolt needs power.
local access_bench = require("@helpers/access_bench")
local clock = require("@helpers/clock")

local LEAF = 5
local ENGINEERING = "\"access\": \"station.engineering\""

-- ---- control: a passing captain opens the same leaf unbolted.
assert(
    access_bench.bump_admits("captain", "(5, 1, \"airlock\", { " .. ENGINEERING .. " })"),
    "a passing captain opens the unbolted leaf"
)

-- ---- bolted: the same captain, the same card, and the leaf stays shut.
t.world(
    access_bench.source(
        "bolted leaf",
        access_bench.spawn("captain", 3) .. ", (5, 1, \"airlock\", { " .. ENGINEERING .. ", \"bolted\": true })",
        ""
    ),
    0
)
local bolted_captain = t.join("captain")
t.run_seconds(1.0)
local bolted_door = assert(t.door_at(LEAF, 1), "the bolted leaf exists")
assert(bolted_door.powered, "the grid feeds the bolted leaf")
assert(bolted_door.latches.bolted, "the leaf is placed bolted")
access_bench.bump(bolted_captain, LEAF)
assert(not assert(t.door_at(LEAF, 1)).open, "a bolt holds a passing captain's leaf shut")
assert(assert(t.door_at(LEAF, 1)).latches.bolted, "and the bolt is still set")

-- ---- unpowered: a crowbar pry on a bolted leaf with no power stays shut.
t.world(
    access_bench.source(
        "pried bolt",
        access_bench.spawn("captain", 3) .. ", (5, 1, \"airlock\", { " .. ENGINEERING .. ", \"bolted\": true })",
        "(3, 1, \"crowbar\")"
    ),
    0
)
local pryer = t.join("captain")
t.run_seconds(1.0)
t.click(pryer, 3, 1, assert(t.target_at(pryer, 3, 1, "crowbar")))
t.run_ticks(2)
assert(t.hands(pryer).held == "crowbar", "the crowbar is in hand")
t.move(pryer, "east")
t.run_ticks(5)
t.outage()
t.run_ticks(2)
assert(not assert(t.door_at(LEAF, 1)).powered, "the breaker tripped")
t.click(pryer, 5, 1, assert(t.target_at(pryer, 5, 1)))
t.run_ticks(clock.deadline_ticks(2.5) + 10) -- the crowbar's pry, had it started
assert(not assert(t.door_at(LEAF, 1)).open, "a crowbar does not pry a bolted, unpowered leaf")
assert(assert(t.door_at(LEAF, 1)).latches.bolted, "the bolt still holds after the attempt")

-- The crowbar's pre-check refuses a bolted leaf before any pry starts: no
-- forced door operation is on the record. The ledger key is the engine's
-- snake_case event name for `sim.door.*` orders (`door_operation`); the
-- positive control below shows the same query finds a forced open.
local function forced_door_operations(): number
    local forced = 0
    for _, row in ipairs(t.ledger_rows("door_operation")) do
        if row.forced == true then
            forced += 1
        end
    end
    return forced
end
assert(forced_door_operations() == 0, "the pre-check skipped the pry: no forced door operation")

-- ---- positive control: the same crowbar on an unbolted, dark leaf does pry it
-- open, and that forced open is on the record under the same key.
access_bench.world("pried open", access_bench.spawn("captain", 3) .. ", (5, 1, \"airlock\")", "(3, 1, \"crowbar\")")
local opener = t.join("captain")
t.run_seconds(1.0)
t.click(opener, 3, 1, assert(t.target_at(opener, 3, 1, "crowbar")))
t.run_ticks(2)
t.move(opener, "east")
t.run_ticks(5)
t.outage()
t.run_ticks(2)
assert(not assert(t.door_at(LEAF, 1)).powered, "the breaker tripped for the control")
t.click(opener, 5, 1, assert(t.target_at(opener, 5, 1)))
t.run_ticks(clock.deadline_ticks(2.5) + clock.deadline_ticks(0.6) + 10) -- the 2.5 s pry, then the 0.6 s swing
assert(assert(t.door_at(LEAF, 1)).open, "the crowbar pries an unbolted, dark leaf open")
assert(forced_door_operations() == 1, "and the forced open is on the ledger under door_operation")

-- A bolt holds a leaf shut whatever the card says. Cases: a passing captain
-- cannot open a bolted leaf; a crowbar's pre-check skips a bolted dark leaf;
-- an unbolted dark leaf pries open (the control); the emergency latch admits an
-- assistant with no permission, and an identical leaf without it refuses them.
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
        access_bench.spawn("captain", 3)
            .. ", (5, 1, \"airlock\", { "
            .. ENGINEERING
            .. ", \"bolted\": true })",
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

-- ---- pre-check: a crowbar pry on a bolted, dark leaf stays shut.
t.world(
    access_bench.source(
        "pried bolt",
        access_bench.spawn("captain", 3)
            .. ", (5, 1, \"airlock\", { "
            .. ENGINEERING
            .. ", \"bolted\": true })",
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
access_bench.world(
    "pried open",
    access_bench.spawn("captain", 3) .. ", (5, 1, \"airlock\")",
    "(3, 1, \"crowbar\")"
)
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
-- The 2.5 s pry, then the 0.6 s swing.
t.run_ticks(clock.deadline_ticks(2.5) + clock.deadline_ticks(0.6) + 10)
assert(assert(t.door_at(LEAF, 1)).open, "the crowbar pries an unbolted, dark leaf open")
assert(forced_door_operations() == 1, "and the forced open is on the ledger under door_operation")

-- ---- emergency: the emergency latch waives the access check.
-- Two engineering leaves on one corridor: the first is placed on the emergency
-- latch, the second is not. An assistant with no permission passes the first
-- and is refused at the second.
access_bench.world(
    "emergency latch",
    access_bench.spawn("assistant", 3)
        .. ", "
        .. access_bench.leaf(5, "airlock.engineering", '{ "emergency": true }')
        .. ", "
        .. access_bench.leaf(9, "airlock.engineering"),
    ""
)
local escaper = t.join("assistant")
t.run_seconds(1.0)
assert(assert(t.door_at(5, 1)).latches.emergency, "the first leaf is placed on the emergency latch")
assert(not assert(t.door_at(9, 1)).latches.emergency, "the second leaf is not")
access_bench.bump(escaper, 5)
assert(
    assert(t.door_at(5, 1)).open,
    "the emergency latch admits an assistant who holds no permission"
)
access_bench.pass_through(escaper, 5)
local unlatched_refusals = #t.ledger_rows("door_denied")
access_bench.bump(escaper, 9)
assert(not assert(t.door_at(9, 1)).open, "the same leaf without the latch refuses that assistant")
assert(#t.ledger_rows("door_denied") > unlatched_refusals, "and that refusal is on the record")

-- ---- a completion belongs to the controller that issued it: a closet's latch
-- switch beside an airlock leaves the airlock's handlers faultless and silent.
access_bench.world(
    "closet beside airlock",
    access_bench.spawn("captain", 3)
        .. ", "
        .. access_bench.leaf(4, "crate.secure")
        .. ", "
        .. access_bench.leaf(8, "airlock.engineering"),
    "(3, 1, \"id_captain\")"
)
local keeper = t.join("captain")
t.run_seconds(1.0)
local _ = t.sounds(keeper)
t.click(keeper, 3, 1, assert(t.target_at(keeper, 3, 1, "id_captain")))
t.run_ticks(2)
t.click(keeper, 4, 1, assert(t.target_at(keeper, 4, 1, "crate.secure")))
t.run_ticks(2)
local unlocked = false
for _, row in ipairs(t.ledger_rows("latch_set")) do
    if row.latch == "locked" and row.on == false then
        unlocked = true
    end
end
assert(unlocked, "the ID unlocks the crate through a latch switch")
local heard = t.sounds(keeper)
assert(table.find(heard, "closet_unlock") ~= nil, "the crate answers its own switch")
-- A controller that took the crate's completion would queue it for a guest:
-- the queue is the crate's `device_outbox` var, written on the crate alone.
for _, row in ipairs(t.ledger_rows("var_set")) do
    assert(
        not tostring(row.key):find("device_outbox", 1, true),
        "the airlock's controller queued nothing for the crate's completion"
    )
end
assert(#t.script_errors() == 0, "no airlock handler faults on the closet's completion")

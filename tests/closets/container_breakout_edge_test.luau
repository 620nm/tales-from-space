-- Breakouts that end or share a holder in the awkward ways
-- (lib/closets/breakout.luau; the plain cases: container_breakout_test): a
-- re-push after an interrupted escape, a lock and a weld together, a holder
-- destroyed or an occupant dropped mid-wait, two occupants and a freezer.
-- Not reachable from a player's seat: the `latch_unconfirmed`, `open_refused`
-- and post-wait `incapacitated` lapses, and a task canceled with no Luau.
local clock = require("@helpers/clock")
local bench = require("@helpers/container_bench")

local HOLDER_X = bench.HOLDER_X
local HOLDER_Y = bench.HOLDER_Y
local ONLOOKER_LINE = bench.ONLOOKER_LINE
local OWN_LINE = bench.OWN_LINE
local FAILED_LINE = bench.FAILED_LINE
local BROKEN_OUT = bench.BROKEN_OUT
local LAPSED = bench.LAPSED
local LATCH_ORDER_TICKS = bench.LATCH_ORDER_TICKS
-- The remover's sprite is the welder's: it lies one tile over, not under it.
local REMOVER = "lunatic/tfs:closet_cut_test_remover"
local REMOVER_X = bench.HOLDER_X + 1
local open_bench = bench.open
local heard_count = bench.heard_count
local state_of = bench.state_of
local tile_has_body = bench.tile_has_body
local click_holder = bench.click_holder
local pick_up_here = bench.pick_up_here
local empty_click_holder = bench.empty_click_holder
local seal_occupant_in = bench.seal_occupant_in
local toggle_weld = bench.toggle_weld
local light_welder = bench.light_welder
local push_and_start = bench.push_and_start
local run_until = bench.run_until
local last_latch_seq = bench.last_latch_seq
local field = bench.field

-- ---- a push after an interrupted escape starts a new one.
do
    local occupant, engineer = open_bench("repush breakout", "locker")
    seal_occupant_in(occupant, engineer, "locker", false)
    light_welder(engineer)
    toggle_weld(engineer, "locker")
    local first_start = push_and_start(occupant)
    run_until(first_start + clock.deadline_ticks(10.0))
    toggle_weld(engineer, "locker")
    local interruptions = #t.ledger_rows("DoAfterInterrupted")
    empty_click_holder(engineer, "locker")
    assert(state_of(HOLDER_X, HOLDER_Y) == "open", "the engineer opens the unwelded locker")
    assert(#t.ledger_rows("DoAfterInterrupted") == interruptions + 1, "the open interrupts the first escape")

    -- Shutting the open locker takes the dumped occupant back in; weld it again.
    empty_click_holder(engineer, "locker")
    assert(state_of(HOLDER_X, HOLDER_Y) == "closed", "the locker shuts on the dumped occupant")
    assert(not tile_has_body(HOLDER_X, HOLDER_Y, occupant), "the occupant is inside again")
    t.run_seconds(4.1)
    light_welder(engineer)
    toggle_weld(engineer, "locker")
    assert(last_latch_seq("welded", true) ~= nil, "the weld is back on")

    local second_start = push_and_start(occupant)
    assert(heard_count(occupant, "start forcing your way out") == 2, "the new push starts a new escape")
    assert(heard_count(engineer, bench.SHAKE_LINE) == 2, "and cues the onlooker again")
    run_until(second_start + bench.breakout_ticks() - 1)
    assert(state_of(HOLDER_X, HOLDER_Y) == "closed", "the new escape is still waiting one tick early")
    t.run_ticks(LATCH_ORDER_TICKS + 1)
    assert(state_of(HOLDER_X, HOLDER_Y) == "open", "the new escape opens the locker")
    assert(#t.ledger_rows(BROKEN_OUT) == 1, "one break-out is recorded")
    assert(#t.ledger_rows(LAPSED) == 0, "nothing lapsed")
    assert(#t.script_errors() == 0, "the re-pushed escape raises no script error")
end

-- ---- a lock and a weld together are both cleared.
do
    local occupant, engineer = open_bench("locked welded breakout", "crate.secure")
    pick_up_here(engineer, "id_captain")
    click_holder(engineer, "crate.secure")
    assert(heard_count(engineer, "You unlock") == 1, "the command ID unlocks the secure crate")
    seal_occupant_in(occupant, engineer, "crate.secure", true)
    pick_up_here(engineer, "id_captain")
    click_holder(engineer, "crate.secure")
    assert(heard_count(engineer, "You lock") == 1, "the command ID locks the occupied crate")
    t.drop(engineer)
    t.run_ticks(2)
    light_welder(engineer)
    toggle_weld(engineer, "crate.secure")
    assert(heard_count(engineer, "You weld the") == 1, "the lit welder welds the locked crate")

    local started = push_and_start(occupant)
    run_until(started + bench.breakout_ticks() + LATCH_ORDER_TICKS + 1)
    assert(state_of(HOLDER_X, HOLDER_Y) == "open", "the crate opens with both latches on")
    local broke = t.ledger_rows(BROKEN_OUT)
    assert(#broke == 1, "one break-out is recorded")
    assert(field(broke[1], "cleared") == "locked,welded", "both holding latches are cleared, in order")
    assert(field(broke[1], "broken") == "broken", "and the lock is broken")
    local lock_off = assert(last_latch_seq("locked", false), "the lock clearing is a latch row")
    local weld_off = assert(last_latch_seq("welded", false), "the weld clearing is a latch row")
    assert(lock_off < broke[1].seq and weld_off < broke[1].seq, "both clearings precede the record")
    assert(#t.ledger_rows(LAPSED) == 0, "nothing lapsed")
    assert(#t.script_errors() == 0, "the escape raises no script error")
end

-- ---- a freezer breaks out like a locker.
do
    local occupant, engineer = open_bench("freezer breakout", "freezer")
    seal_occupant_in(occupant, engineer, "freezer", true)
    light_welder(engineer)
    toggle_weld(engineer, "freezer")
    local started = push_and_start(occupant)
    run_until(started + bench.breakout_ticks() - 1)
    assert(state_of(HOLDER_X, HOLDER_Y) == "closed", "the freezer is shut one tick before 120 s")
    t.run_ticks(LATCH_ORDER_TICKS + 1)
    assert(state_of(HOLDER_X, HOLDER_Y) == "open", "the freezer is open after 120 s")
    local broke = t.ledger_rows(BROKEN_OUT)
    assert(#broke == 1, "one break-out is recorded")
    assert(field(broke[1], "cleared") == "welded", "the weld is the cleared latch")
    assert(field(broke[1], "broken") == nil, "a freezer declares no broken latch")
    t.run_ticks(bench.CUE_TICKS)
    assert(heard_count(occupant, OWN_LINE) == 1, "the occupant hears the break-out line")
    assert(#t.script_errors() == 0, "the escape raises no script error")
end

-- ---- the holder destroyed mid-wait: the wait is interrupted, nothing breaks.
do
    local occupant, engineer = open_bench(
        "destroyed holder breakout",
        "crate",
        "(" .. REMOVER_X .. ", " .. bench.ENGINEER_Y .. ', "' .. REMOVER .. '"),'
    )
    seal_occupant_in(occupant, engineer, "crate", true)
    light_welder(engineer)
    toggle_weld(engineer, "crate")
    local started = push_and_start(occupant)
    run_until(started + clock.deadline_ticks(10.0))
    toggle_weld(engineer, "crate")
    t.drop(engineer)
    t.run_ticks(2)
    pick_up_here(engineer, REMOVER, REMOVER_X, bench.ENGINEER_Y)
    local interruptions = #t.ledger_rows("DoAfterInterrupted")
    click_holder(engineer, "crate")
    t.run_seconds(3.0)
    assert(t.structure_at(HOLDER_X, HOLDER_Y) == nil, "the engineer takes the occupied crate apart")
    assert(#t.ledger_rows("DoAfterInterrupted") == interruptions + 1, "the destruction interrupts the wait")
    assert(tile_has_body(HOLDER_X, HOLDER_Y, occupant), "the occupant is dumped on the tile")
    run_until(started + bench.breakout_ticks() + 3)
    assert(#t.ledger_rows(BROKEN_OUT) == 0, "no break-out is recorded")
    assert(#t.ledger_rows(LAPSED) == 0, "the canceled escape lapses nothing")
    assert(#t.ledger_rows("DoAfterInterrupted") == interruptions + 1, "and nothing more is interrupted")
    assert(heard_count(occupant, OWN_LINE) == 0, "the occupant hears no break-out line")
    assert(#t.script_errors() == 0, "the destroyed holder raises no script error")
end

-- ---- an occupant who goes down mid-wait ends the escape; the holder stays shut.
do
    local occupant, engineer = open_bench("incapacitated breakout", "locker")
    seal_occupant_in(occupant, engineer, "locker", false)
    light_welder(engineer)
    toggle_weld(engineer, "locker")
    local started = push_and_start(occupant)
    run_until(started + clock.deadline_ticks(10.0))
    local interruptions = #t.ledger_rows("DoAfterInterrupted")
    t.set_health(occupant, { brute = 100 })
    t.run_ticks(2)
    assert(#t.ledger_rows("DoAfterInterrupted") == interruptions + 1, "incapacity interrupts the wait")
    assert(heard_count(occupant, FAILED_LINE) == 1, "the occupant still shut in hears the push fail")
    run_until(started + bench.breakout_ticks() + 3)
    assert(state_of(HOLDER_X, HOLDER_Y) == "closed", "the locker stays shut")
    assert(#t.ledger_rows(BROKEN_OUT) == 0, "no break-out is recorded")
    assert(#t.ledger_rows("DoAfterInterrupted") == interruptions + 1, "and nothing more is interrupted")
    -- A downed body inside a holder also trips the body's own `mob.life`
    -- handler (bodies/human.luau); only the closet lib's errors count here.
    for _, failure in ipairs(t.script_errors()) do
        assert(string.find(failure.file, "closet", 1, true) == nil, "the closet lib raised: " .. failure.why)
    end
end

-- ---- two occupants: the first escape opens the holder under the second wait.
do
    local first, engineer = open_bench("two occupant breakout", "locker")
    local second = t.join("medic")
    t.run_ticks(3)
    bench.seal_two_in(first, second, engineer, "locker")
    light_welder(engineer)
    toggle_weld(engineer, "locker")
    local started = push_and_start(first)
    run_until(started + clock.deadline_ticks(10.0))
    t.move(second, "north")
    t.run_ticks(2)
    assert(heard_count(second, "start forcing your way out") == 1, "the second occupant starts their own escape")
    assert(heard_count(engineer, bench.SHAKE_LINE) == 2, "the onlooker sees each start")

    run_until(started + bench.breakout_ticks() - 1)
    assert(state_of(HOLDER_X, HOLDER_Y) == "closed", "the holder is shut one tick before the first escape")
    local interruptions = #t.ledger_rows("DoAfterInterrupted")
    t.run_ticks(LATCH_ORDER_TICKS + 1)
    assert(state_of(HOLDER_X, HOLDER_Y) == "open", "the first escape opens the holder")
    assert(#t.ledger_rows(BROKEN_OUT) == 1, "one break-out is recorded")
    t.run_ticks(2)
    assert(#t.ledger_rows("DoAfterInterrupted") == interruptions + 1, "the open interrupts the second wait")
    assert(tile_has_body(HOLDER_X, HOLDER_Y, first) and tile_has_body(HOLDER_X, HOLDER_Y, second), "both are out")
    t.run_ticks(5)
    assert(heard_count(first, OWN_LINE) == 1, "the first occupant hears the break-out line")
    assert(heard_count(second, OWN_LINE) == 0, "the second occupant does not")
    assert(heard_count(second, FAILED_LINE) == 0, "nor a failure, being out")
    assert(heard_count(second, ONLOOKER_LINE) == 1, "the second occupant hears the cue as an onlooker")
    assert(#t.ledger_rows(LAPSED) == 0, "nothing lapsed")
    assert(#t.script_errors() == 0, "two occupants raise no script error")
end

-- ---- two occupants whose waits end on the same tick: one breaks out, one lapses.
do
    local first, engineer = open_bench("same tick breakout", "locker")
    local second = t.join("medic")
    t.run_ticks(3)
    bench.seal_two_in(first, second, engineer, "locker")
    light_welder(engineer)
    toggle_weld(engineer, "locker")
    t.move(first, "north")
    t.move(second, "north")
    t.run_ticks(2)
    local started = t.now()
    assert(heard_count(first, "start forcing your way out") == 1, "the first occupant starts an escape")
    assert(heard_count(second, "start forcing your way out") == 1, "the second occupant starts an escape")
    run_until(started + bench.breakout_ticks() + 6)
    local broke = #t.ledger_rows(BROKEN_OUT)
    local lapses = #t.ledger_rows(LAPSED)
    assert(state_of(HOLDER_X, HOLDER_Y) == "open", "the holder opens")
    assert(broke == 1 and lapses == 1, "one broke out, one lapsed: " .. broke .. " broke, " .. lapses .. " lapsed")
    local reason = bench.field(t.ledger_rows(LAPSED)[1], "reason")
    assert(reason == "not_secured", "the loser finds the holder no longer secured: " .. tostring(reason))
    assert(#t.script_errors() == 0, "the shared end raises no script error")
end

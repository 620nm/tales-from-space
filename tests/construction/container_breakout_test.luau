-- A shut-in occupant pushes out of a closet (`closets.dm:1085-1118`): the
-- closet lib answers `container.resist` (lib/closets/breakout.luau). An
-- unsecured closet opens at once; a welded or locked one gives way after its
-- 120 seconds, clearing every holding latch (`closets.dm:1141-1146`), then
-- opens. Rows are read by their snake_case words; the pack's own are
-- `lunatic/tfs:closet_broken_out` and `closet_breakout_lapsed`. Interrupted
-- and shared-holder cases: container_breakout_edge_test.
local clock = require("@helpers/clock")
local bench = require("@helpers/container_bench")

local HOLDER_X = bench.HOLDER_X
local HOLDER_Y = bench.HOLDER_Y
local ONLOOKER_LINE = bench.ONLOOKER_LINE
local OWN_LINE = bench.OWN_LINE
local FAILED_LINE = bench.FAILED_LINE
local SHAKE_LINE = bench.SHAKE_LINE
local BROKEN_OUT = bench.BROKEN_OUT
local LAPSED = bench.LAPSED
local LATCH_ORDER_TICKS = bench.LATCH_ORDER_TICKS
local CUE_TICKS = bench.CUE_TICKS
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
local last_open_seq = bench.last_open_seq
local field = bench.field
local triggered_by = bench.triggered_by

-- ---- an unsecured closet opens on the first push, with no wait and no step.
do
    local occupant, engineer = open_bench("unsecured breakout", "locker")
    seal_occupant_in(occupant, engineer, "locker", false)
    local opened = #t.ledger_rows("container_opened")
    local refused = #t.ledger_rows("container_resist_refused")
    local waits = #t.ledger_rows("DoAfterStarted")
    t.move(occupant, "north")
    t.run_ticks(2)
    assert(state_of(HOLDER_X, HOLDER_Y) == "open", "an unsecured push opens the locker at once")
    assert(#t.ledger_rows("container_opened") == opened + 1, "the open is on the record")
    local opening = t.ledger_rows("container_opened")
    assert(
        opening[#opening].actor.kind == "script" and triggered_by(opening[#opening]) == t.body_id(occupant),
        "the closet lib opened it for the pushing occupant, not the engineer"
    )
    assert(#t.ledger_rows("container_resist_refused") == refused, "no refusal is recorded")
    assert(heard_count(occupant, "start forcing your way out") == 0, "no breakout begins")
    assert(#t.ledger_rows(BROKEN_OUT) == 0, "nothing was broken")
    assert(#t.ledger_rows(LAPSED) == 0, "nothing lapsed")
    assert(#t.ledger_rows("DoAfterStarted") == waits, "no wait is parked")
    assert(heard_count(engineer, SHAKE_LINE) == 0, "the onlooker hears no shake")
    assert(tile_has_body(HOLDER_X, HOLDER_Y, occupant), "the push is not a tile step")
end

-- ---- a welded locker gives way after 120 s; repeated pushes keep the clock.
do
    local occupant, engineer = open_bench("welded breakout", "locker")
    seal_occupant_in(occupant, engineer, "locker", false)
    light_welder(engineer)
    toggle_weld(engineer, "locker")
    assert(heard_count(engineer, "You weld the") == 1, "the engineer welds the locker shut")
    local weld_on = assert(last_latch_seq("welded", true), "the weld lands as a latch row")

    local refused = #t.ledger_rows("container_resist_refused")
    local waits = #t.ledger_rows("DoAfterStarted")
    local started = push_and_start(occupant)
    assert(heard_count(engineer, SHAKE_LINE) == 1, "the onlooker sees the closet begin to shake")
    for _, offset in ipairs({ 10.0, 59.0, 61.0, 100.0 }) do
        run_until(started + clock.deadline_ticks(offset))
        t.move(occupant, "north")
        t.run_ticks(1)
    end
    assert(heard_count(occupant, "start forcing your way out") == 1, "pushes do not begin a second breakout")
    assert(heard_count(engineer, SHAKE_LINE) == 1, "nor a second start cue")
    assert(#t.ledger_rows("container_resist_refused") == refused, "duplicate pushes are absorbed silently")
    assert(#t.ledger_rows(BROKEN_OUT) == 0, "nothing broke early")

    run_until(started + bench.breakout_ticks() - 1)
    assert(state_of(HOLDER_X, HOLDER_Y) == "closed", "the locker is shut one tick before 120 s")
    assert(last_latch_seq("welded", false) == nil, "the weld is still on one tick before 120 s")
    t.run_ticks(1)
    assert(last_latch_seq("welded", false) ~= nil, "the wait's end clears the weld")
    assert(state_of(HOLDER_X, HOLDER_Y) == "closed", "the locker is still shut while the latch order lands")
    t.run_ticks(LATCH_ORDER_TICKS)
    assert(state_of(HOLDER_X, HOLDER_Y) == "open", "the locker is open one latch-order tick after 120 s")
    assert(tile_has_body(HOLDER_X, HOLDER_Y, occupant), "the occupant is dumped on the tile")
    assert(
        t.ledger_rows("container_opened")[#t.ledger_rows("container_opened")].tick
            == started + bench.breakout_ticks() + LATCH_ORDER_TICKS,
        "the open lands exactly one tick after the wait"
    )

    local broke = t.ledger_rows(BROKEN_OUT)
    assert(#broke == 1, "one break-out is recorded")
    assert(field(broke[1], "cleared") == "welded", "the weld is the cleared latch")
    assert(field(broke[1], "broken") == nil, "a locker declares no broken latch")
    local weld_off = assert(last_latch_seq("welded", false))
    assert(weld_off > weld_on and weld_off < broke[1].seq, "the weld clearing is a latch row before the record")
    assert(last_open_seq() > broke[1].seq, "the open follows the record")
    local opening = t.ledger_rows("container_opened")
    assert(
        opening[#opening].actor.kind == "script" and triggered_by(opening[#opening]) == t.body_id(occupant),
        "the bust-open is the occupant's own open"
    )
    assert(#t.ledger_rows(LAPSED) == 0, "nothing lapsed")
    assert(#t.ledger_rows("DoAfterStarted") == waits + 2, "the 120 s wait parks two 60 s segments")
    assert(#t.ledger_rows("DoAfterInterrupted") == 0, "nothing interrupted the wait")
    assert(#t.script_errors() == 0, "the breakout raises no script error")

    -- The cues follow the confirmed open by one more tick.
    assert(heard_count(occupant, OWN_LINE) == 0, "no cue before the open is confirmed")
    t.run_ticks(CUE_TICKS)
    assert(heard_count(occupant, OWN_LINE) == 1, "the occupant hears the break-out line")
    assert(heard_count(engineer, ONLOOKER_LINE) == 1, "the onlooker hears the cue exactly once")
    assert(heard_count(occupant, ONLOOKER_LINE) == 0, "the occupant hears only their own line")
    assert(heard_count(occupant, FAILED_LINE) == 0, "a break-out is no failure")
    t.run_ticks(5)
    assert(heard_count(engineer, ONLOOKER_LINE) == 1, "and never again")

    -- The weld is gone: the locker closes and opens like any other.
    empty_click_holder(engineer, "locker")
    assert(state_of(HOLDER_X, HOLDER_Y) == "closed", "the unwelded locker closes")
    click_holder(engineer, "locker")
    assert(state_of(HOLDER_X, HOLDER_Y) == "open", "and opens again")
end

-- ---- unwelding mid-wait: nothing breaks at the boundary, the next push opens.
do
    local occupant, engineer = open_bench("unwelded breakout", "locker")
    seal_occupant_in(occupant, engineer, "locker", false)
    light_welder(engineer)
    toggle_weld(engineer, "locker")
    local started = push_and_start(occupant)

    run_until(started + clock.deadline_ticks(30.0))
    toggle_weld(engineer, "locker")
    assert(heard_count(engineer, "You unweld the") == 1, "the engineer unwelds the locker")

    local refused = #t.ledger_rows("container_resist_refused")
    run_until(started + bench.breakout_ticks() + 2)
    assert(state_of(HOLDER_X, HOLDER_Y) == "closed", "nothing opens at the boundary")
    assert(#t.ledger_rows(BROKEN_OUT) == 0, "no break-out is recorded")
    local lapses = t.ledger_rows(LAPSED)
    assert(#lapses == 1, "the lapsed wait is on the record")
    assert(field(lapses[1], "reason") == "not_secured", "because nothing holds the locker shut")
    assert(lapses[1].tick == started + bench.breakout_ticks(), "at the end of the wait")
    assert(#t.ledger_rows("container_resist_refused") == refused, "the pack, not the engine, owns the lapse")
    assert(heard_count(engineer, ONLOOKER_LINE) == 0, "the onlooker hears nothing")
    assert(heard_count(occupant, FAILED_LINE) == 1, "the occupant hears the push fail")

    local opened = #t.ledger_rows("container_opened")
    t.move(occupant, "north")
    t.run_ticks(2)
    assert(state_of(HOLDER_X, HOLDER_Y) == "open", "the next push opens the unsecured locker")
    assert(#t.ledger_rows("container_opened") == opened + 1, "that open is on the record")
    assert(#t.ledger_rows(BROKEN_OUT) == 0, "and still no break-out")
end

-- ---- an external open mid-wait interrupts it: no break-out, no lapse.
do
    local occupant, engineer = open_bench("opened breakout", "locker")
    seal_occupant_in(occupant, engineer, "locker", false)
    light_welder(engineer)
    toggle_weld(engineer, "locker")
    local started = push_and_start(occupant)
    run_until(started + clock.deadline_ticks(10.0))
    toggle_weld(engineer, "locker")
    local baseline = #t.ledger_rows("DoAfterInterrupted")
    empty_click_holder(engineer, "locker")
    assert(state_of(HOLDER_X, HOLDER_Y) == "open", "the engineer opens the unwelded locker")
    assert(#t.ledger_rows("DoAfterInterrupted") == baseline + 1, "the open interrupts the wait on the record")
    run_until(started + bench.breakout_ticks() + 3)
    assert(#t.ledger_rows("DoAfterInterrupted") == baseline + 1, "and nothing more is interrupted")
    assert(#t.ledger_rows(LAPSED) == 0, "an interrupted wait lapses nothing")
    assert(heard_count(occupant, FAILED_LINE) == 0, "the dumped occupant hears no failure")
    assert(#t.script_errors() == 0, "the interrupted wait raises no script error")
    assert(#t.ledger_rows(BROKEN_OUT) == 0, "no break-out is recorded")
    assert(heard_count(engineer, ONLOOKER_LINE) == 0, "the onlooker hears nothing")
end

-- ---- a locked secure crate breaks its lock; the ID toggle then refuses.
do
    local occupant, engineer = open_bench("secure crate breakout", "crate.secure")
    pick_up_here(engineer, "id_captain")
    click_holder(engineer, "crate.secure")
    assert(heard_count(engineer, "You unlock") == 1, "the command ID unlocks the secure crate")
    seal_occupant_in(occupant, engineer, "crate.secure", true)
    pick_up_here(engineer, "id_captain")
    click_holder(engineer, "crate.secure")
    assert(heard_count(engineer, "You lock") == 1, "the command ID locks the occupied crate")
    empty_click_holder(engineer, "crate.secure")
    assert(state_of(HOLDER_X, HOLDER_Y) == "closed", "the locked crate stays shut")

    local started = push_and_start(occupant)
    run_until(started + bench.breakout_ticks() - 1)
    assert(state_of(HOLDER_X, HOLDER_Y) == "closed", "the crate is shut one tick before 120 s")
    t.run_ticks(LATCH_ORDER_TICKS + 1)
    assert(state_of(HOLDER_X, HOLDER_Y) == "open", "the crate is open one latch-order tick after 120 s")

    local broke = t.ledger_rows(BROKEN_OUT)
    assert(#broke == 1, "one break-out is recorded")
    assert(field(broke[1], "cleared") == "locked", "the lock is the cleared latch")
    assert(field(broke[1], "broken") == "broken", "the crate's lock is declared broken")
    local lock_off = assert(last_latch_seq("locked", false), "the lock clearing is a latch row")
    local break_on = assert(last_latch_seq("broken", true), "the break is a latch row")
    assert(lock_off < broke[1].seq and break_on < broke[1].seq, "both latch rows precede the record")
    assert(last_open_seq() > broke[1].seq, "the open follows the record")
    assert(#t.ledger_rows(LAPSED) == 0, "nothing lapsed")
    t.run_ticks(CUE_TICKS)
    assert(heard_count(occupant, OWN_LINE) == 1, "the occupant hears the break-out line")
    assert(heard_count(engineer, ONLOOKER_LINE) == 1, "the onlooker hears the cue exactly once")
    assert(heard_count(occupant, ONLOOKER_LINE) == 0, "the occupant hears only their own line")

    -- The occupant steps off before the crate is shut again; the standing-body
    -- veto is container_close_veto_test's.
    t.move(occupant, "west")
    t.run_seconds(0.25)
    assert(not tile_has_body(HOLDER_X, HOLDER_Y, occupant), "the occupant steps off the crate's tile")

    -- The broken lock takes no ID toggle, and the crate is no longer locked.
    empty_click_holder(engineer, "crate.secure")
    assert(state_of(HOLDER_X, HOLDER_Y) == "closed", "the broken crate closes")
    pick_up_here(engineer, "id_captain")
    click_holder(engineer, "crate.secure")
    assert(heard_count(engineer, "lock of the") >= 1, "the ID toggle names the broken lock")
    empty_click_holder(engineer, "crate.secure")
    assert(state_of(HOLDER_X, HOLDER_Y) == "open", "the refused toggle left the crate unlocked")
end

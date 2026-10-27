-- A shut-in occupant pushes out of a closet (`closets.dm:1085-1118`): the
-- closet lib answers `container.resist` (lib/closets/closet.luau). An
-- unsecured closet opens at once; a welded or locked one gives way after its
-- 120 seconds, clearing every holding latch (`closets.dm:1141-1146`), then
-- opens. Rows are read by their snake_case words; the pack's own are
-- `lunatic/tfs:closet_broken_out` and `closet_breakout_lapsed`.
local clock = require("@helpers/clock")

local OCCUPANT_X = 4
local HOLDER_X = 5
local HOLDER_Y = 2
local ENGINEER_Y = 3
local ONLOOKER_LINE = "successfully broke out of the"
local OWN_LINE = "You break your way out."
local BROKEN_OUT = "lunatic/tfs:closet_broken_out"
local LAPSED = "lunatic/tfs:closet_breakout_lapsed"
-- The latch orders of the bust-open complete on the tick the wait ends; the
-- occupant opens the door one tick later (lib/closets/closet.luau:bust_open).
local LATCH_ORDER_TICKS = 1
-- The shake and lines wait one tick for the open to be read back.
local CUE_TICKS = 1

local BREAKOUT_TICKS: number

local heard_log: { [number]: { string } } = {}

local function bench_source(name: string, structures: string, items: string): string
    return [==[ (
        name: "]==] .. name .. [==[",
        legend: {
            ' ': (composition: (substrate: Named("space"))),
            '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
            '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        },
        levels: [(
            rows: ["#########", "#.......#", "#.......#", "#.......#", "#########"],
            structures: [
                (]==] .. OCCUPANT_X .. [==[, ]==] .. HOLDER_Y .. [==[, "player_spawn", { "jobs": "assistant" }),
                (]==] .. HOLDER_X .. [==[, ]==] .. ENGINEER_Y .. [==[, "player_spawn", { "jobs": "engineer" }),
                ]==] .. structures .. [==[
            ],
            items: [
                (]==] .. HOLDER_X .. [==[, ]==] .. ENGINEER_Y .. [==[, "welder"),
                (]==] .. HOLDER_X .. [==[, ]==] .. ENGINEER_Y .. [==[, "id_captain"),
            ],
        )],
    ) ]==]
end

-- Loads a bench with one holder; returns the occupant and the engineer.
local function open_bench(name: string, holder: string): (number, number)
    t.world(bench_source(name, "(" .. HOLDER_X .. ", " .. HOLDER_Y .. ', "' .. holder .. '"),', ""), 0)
    BREAKOUT_TICKS = clock.deadline_ticks(120.0)
    heard_log = {}
    local occupant = t.join("assistant")
    local engineer = t.join("engineer")
    t.run_ticks(3)
    return occupant, engineer
end

local function heard_count(player: number, needle: string): number
    local log = heard_log[player]
    if log == nil then
        log = {}
        heard_log[player] = log
    end
    for _, message in ipairs(t.messages(player)) do
        table.insert(log, message)
    end
    local count = 0
    for _, message in ipairs(log) do
        if string.find(message, needle, 1, true) ~= nil then
            count += 1
        end
    end
    return count
end

local function state_of(x: number, y: number): string
    local structure = assert(t.structure_at(x, y), "the holder remains present")
    return assert(structure.state, "the holder exposes its native state")
end

local function tile_has_body(x: number, y: number, player: number): boolean
    local wanted = t.body_id(player)
    for _, body in ipairs(t.bodies_at(x, y)) do
        if body.id == wanted then
            return true
        end
    end
    return false
end

local function click_holder(player: number, id: string): ()
    t.click(player, HOLDER_X, HOLDER_Y, assert(t.target_at(player, HOLDER_X, HOLDER_Y, id)))
    t.run_ticks(2)
end

local function pick_up_here(player: number, id: string): ()
    t.click(player, HOLDER_X, ENGINEER_Y, assert(t.target_at(player, HOLDER_X, ENGINEER_Y, id)))
    t.run_ticks(2)
    assert(t.hands(player).held == id, "the engineer holds the " .. id)
end

local function empty_click_holder(player: number, id: string): ()
    t.drop(player)
    t.run_ticks(2)
    click_holder(player, id)
end

-- The engineer opens the holder, the occupant gets onto its tile and hides in
-- it, and the holder shuts. A locker is passable open; a crate stays dense, so
-- its occupant climbs on first.
local function seal_occupant_in(occupant: number, engineer: number, id: string, climbs: boolean): ()
    empty_click_holder(engineer, id)
    assert(state_of(HOLDER_X, HOLDER_Y) == "open", "the holder opens for loading")
    if climbs then
        t.use_item(occupant, assert(t.target_at(occupant, HOLDER_X, HOLDER_Y, id)), "alt_primary")
        t.run_ticks(clock.deadline_ticks(1.0) + 3)
    else
        t.move(occupant, "east")
        t.run_seconds(0.25)
    end
    local x, y = t.pos(occupant)
    assert(x == HOLDER_X and y == HOLDER_Y, "the occupant stands on the holder tile")
    t.drag(
        occupant,
        HOLDER_X,
        HOLDER_Y,
        t.body_target(occupant, occupant),
        HOLDER_X,
        HOLDER_Y,
        assert(t.target_at(occupant, HOLDER_X, HOLDER_Y, id))
    )
    t.run_ticks(clock.deadline_ticks(4.0) + 2)
    assert(state_of(HOLDER_X, HOLDER_Y) == "closed", "the holder shuts with the occupant inside")
    assert(not tile_has_body(HOLDER_X, HOLDER_Y, occupant), "the occupant is inside, not on the tile")
end

-- A lit welder toggles the weld; the engineer keeps holding it.
local function toggle_weld(engineer: number, id: string): ()
    click_holder(engineer, id)
    t.run_seconds(4.1)
end

local function light_welder(engineer: number): ()
    pick_up_here(engineer, "welder")
    t.use_self(engineer)
    t.run_ticks(2)
end

-- Pushes the occupant against the shell and returns the tick the wait began.
local function push_and_start(occupant: number): number
    t.move(occupant, "north")
    t.run_ticks(2)
    assert(heard_count(occupant, "start forcing your way out") >= 1, "the occupant hears the push begin")
    return t.now()
end

local function run_until(tick: number): ()
    local remaining = tick - t.now()
    assert(remaining >= 0, "the spec has not run past tick " .. tick)
    if remaining > 0 then
        t.run_ticks(remaining)
    end
end

-- The seq of the last `latch_set` row that switched `latch` to `on`, or nil.
local function last_latch_seq(latch: string, on: boolean): number?
    local found: number? = nil
    for _, row in ipairs(t.ledger_rows("latch_set")) do
        if row.latch == latch and row.on == on then
            found = row.seq
        end
    end
    return found
end

local function last_open_seq(): number
    local opened = t.ledger_rows("container_opened")
    return opened[#opened].seq
end

-- A pack row's declared field (`sim.ledger.record` fields).
local function field(row: SpecLedgerRow, name: string): unknown
    return (row.fields :: { [string]: unknown })[name]
end

-- The body a script-attributed row was triggered by.
local function triggered_by(row: SpecLedgerRow): unknown
    return (row.actor :: { [string]: unknown }).triggered_by
end

-- ---- an unsecured closet opens on the first push, with no wait and no step.
do
    local occupant, engineer = open_bench("unsecured breakout", "locker")
    seal_occupant_in(occupant, engineer, "locker", false)
    local opened = #t.ledger_rows("container_opened")
    local refused = #t.ledger_rows("container_resist_refused")
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
    for _, offset in ipairs({ 10.0, 59.0, 61.0, 100.0 }) do
        run_until(started + clock.deadline_ticks(offset))
        t.move(occupant, "north")
        t.run_ticks(1)
    end
    assert(heard_count(occupant, "start forcing your way out") == 1, "pushes do not begin a second breakout")
    assert(#t.ledger_rows("container_resist_refused") == refused, "duplicate pushes are absorbed silently")
    assert(#t.ledger_rows(BROKEN_OUT) == 0, "nothing broke early")

    run_until(started + BREAKOUT_TICKS - 1)
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
            == started + BREAKOUT_TICKS + LATCH_ORDER_TICKS,
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
    run_until(started + BREAKOUT_TICKS + 2)
    assert(state_of(HOLDER_X, HOLDER_Y) == "closed", "nothing opens at the boundary")
    assert(#t.ledger_rows(BROKEN_OUT) == 0, "no break-out is recorded")
    local lapses = t.ledger_rows(LAPSED)
    assert(#lapses == 1, "the lapsed wait is on the record")
    assert(field(lapses[1], "reason") == "not_secured", "because nothing holds the locker shut")
    assert(lapses[1].tick == started + BREAKOUT_TICKS, "at the end of the wait")
    assert(#t.ledger_rows("container_resist_refused") == refused, "the pack, not the engine, owns the lapse")
    assert(heard_count(engineer, ONLOOKER_LINE) == 0, "the onlooker hears nothing")

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
    empty_click_holder(engineer, "locker")
    assert(state_of(HOLDER_X, HOLDER_Y) == "open", "the engineer opens the unwelded locker")
    local interruptions = #t.ledger_rows("DoAfterInterrupted")
    assert(interruptions >= 1, "the open interrupts the wait on the record")
    run_until(started + BREAKOUT_TICKS + 3)
    assert(#t.ledger_rows("DoAfterInterrupted") == interruptions, "and nothing more is interrupted")
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
    run_until(started + BREAKOUT_TICKS - 1)
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
    assert(heard_count(engineer, ONLOOKER_LINE) == 1, "the onlooker hears the cue exactly once")
    assert(heard_count(occupant, ONLOOKER_LINE) == 0, "the occupant hears only their own line")

    -- The broken lock takes no ID toggle, and the crate is no longer locked.
    empty_click_holder(engineer, "crate.secure")
    assert(state_of(HOLDER_X, HOLDER_Y) == "closed", "the broken crate closes")
    pick_up_here(engineer, "id_captain")
    click_holder(engineer, "crate.secure")
    assert(heard_count(engineer, "lock of the") >= 1, "the ID toggle names the broken lock")
    empty_click_holder(engineer, "crate.secure")
    assert(state_of(HOLDER_X, HOLDER_Y) == "open", "the refused toggle left the crate unlocked")
end

-- A small room with one closet-family holder, an assistant to shut in, an
-- engineer with a welder and a captain's ID, and a medic for a second
-- occupant. Shared by the container breakout specs (lib/closets/breakout.luau).
local clock = require("@helpers/clock")

local bench = {}

bench.OCCUPANT_X = 4
bench.HOLDER_X = 5
bench.HOLDER_Y = 2
bench.ENGINEER_Y = 3
bench.SECOND_OCCUPANT_X = 6
bench.ONLOOKER_LINE = "successfully broke out of the"
bench.OWN_LINE = "You successfully break out of the"
bench.FAILED_LINE = "You fail to break out of the"
bench.SHAKE_LINE = "begins to shake violently"
bench.BROKEN_OUT = "lunatic/tfs:closet_broken_out"
bench.LAPSED = "lunatic/tfs:closet_breakout_lapsed"
-- The latch orders of the bust-open complete on the tick the wait ends; the
-- occupant opens the door one tick later (lib/closets/breakout.luau:bust_open).
bench.LATCH_ORDER_TICKS = 1
-- The shake and lines wait one tick for the open to be read back.
bench.CUE_TICKS = 1

local HOLDER_X = bench.HOLDER_X
local HOLDER_Y = bench.HOLDER_Y
local ENGINEER_Y = bench.ENGINEER_Y

local BREAKOUT_TICKS: number
local bench_name = ""

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
                (]==] .. bench.OCCUPANT_X .. [==[, ]==] .. HOLDER_Y .. [==[, "player_spawn", { "jobs": "assistant" }),
                (]==] .. bench.SECOND_OCCUPANT_X .. [==[, ]==] .. HOLDER_Y .. [==[, "player_spawn", { "jobs": "medic" }),
                (]==] .. HOLDER_X .. [==[, ]==] .. ENGINEER_Y .. [==[, "player_spawn", { "jobs": "engineer" }),
                ]==] .. structures .. [==[
            ],
            items: [
                (]==] .. HOLDER_X .. [==[, ]==] .. ENGINEER_Y .. [==[, "welder"),
                (]==] .. HOLDER_X .. [==[, ]==] .. ENGINEER_Y .. [==[, "id_captain"),
                ]==] .. items .. [==[
            ],
        )],
    ) ]==]
end

-- Loads a bench with one holder (`items` are extra RON item rows on the
-- engineer's tile); returns the occupant and the engineer.
function bench.open(name: string, holder: string, items: string?): (number, number)
    local structures = "(" .. HOLDER_X .. ", " .. HOLDER_Y .. ', "' .. holder .. '"),'
    bench_name = name
    t.world(bench_source(name, structures, items or ""), 0)
    BREAKOUT_TICKS = clock.deadline_ticks(120.0)
    heard_log = {}
    local occupant = t.join("assistant")
    local engineer = t.join("engineer")
    t.run_ticks(3)
    return occupant, engineer
end

-- Ticks covering the 120 s breakout wait under the booted round's rate.
function bench.breakout_ticks(): number
    return BREAKOUT_TICKS
end

-- How many lines containing `needle` the player has ever heard.
function bench.heard_count(player: number, needle: string): number
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

function bench.state_of(x: number, y: number): string
    local structure = assert(t.structure_at(x, y), "the holder remains present")
    return assert(structure.state, "the holder exposes its native state")
end

function bench.tile_has_body(x: number, y: number, player: number): boolean
    local wanted = t.body_id(player)
    for _, body in ipairs(t.bodies_at(x, y)) do
        if body.id == wanted then
            return true
        end
    end
    return false
end

function bench.click_holder(player: number, id: string): ()
    t.click(player, HOLDER_X, HOLDER_Y, assert(t.target_at(player, HOLDER_X, HOLDER_Y, id)))
    t.run_ticks(2)
end

-- The engineer picks `id` up from a tile within reach (their own by default).
function bench.pick_up_here(player: number, id: string, x: number?, y: number?): ()
    local at_x = x or HOLDER_X
    local at_y = y or ENGINEER_Y
    local item = assert(t.target_at(player, at_x, at_y, id), bench_name .. ": no " .. id .. " to pick up")
    t.click(player, at_x, at_y, item)
    t.run_ticks(2)
    assert(t.hands(player).held == id, "the engineer holds the " .. id)
end

function bench.empty_click_holder(player: number, id: string): ()
    t.drop(player)
    t.run_ticks(2)
    bench.click_holder(player, id)
end

-- The engineer opens the holder, the occupant gets onto its tile and hides in
-- it, and the holder shuts. A locker is passable open; a crate stays dense, so
-- its occupant climbs on first.
function bench.seal_occupant_in(occupant: number, engineer: number, id: string, climbs: boolean): ()
    bench.empty_click_holder(engineer, id)
    assert(bench.state_of(HOLDER_X, HOLDER_Y) == "open", "the holder opens for loading")
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
    assert(bench.state_of(HOLDER_X, HOLDER_Y) == "closed", "the holder shuts with the occupant inside")
    assert(not bench.tile_has_body(HOLDER_X, HOLDER_Y, occupant), "the occupant is inside, not on the tile")
end

-- Two bodies walk onto the open locker and the engineer shuts it on both.
function bench.seal_two_in(first: number, second: number, engineer: number, id: string): ()
    bench.empty_click_holder(engineer, id)
    assert(bench.state_of(HOLDER_X, HOLDER_Y) == "open", "the holder opens for loading")
    t.move(first, "east")
    t.move(second, "west")
    t.run_seconds(0.25)
    assert(bench.tile_has_body(HOLDER_X, HOLDER_Y, first), "the first occupant stands on the holder tile")
    assert(bench.tile_has_body(HOLDER_X, HOLDER_Y, second), "the second occupant stands on the holder tile")
    bench.click_holder(engineer, id)
    t.run_ticks(clock.deadline_ticks(4.0) + 2)
    assert(bench.state_of(HOLDER_X, HOLDER_Y) == "closed", "the holder shuts on both occupants")
    assert(not bench.tile_has_body(HOLDER_X, HOLDER_Y, first), "the first occupant is inside")
    assert(not bench.tile_has_body(HOLDER_X, HOLDER_Y, second), "the second occupant is inside")
end

-- A lit welder toggles the weld; the engineer keeps holding it.
function bench.toggle_weld(engineer: number, id: string): ()
    bench.click_holder(engineer, id)
    t.run_seconds(4.1)
end

-- Picks the welder up and leaves it lit, whether or not it was put down lit.
function bench.light_welder(engineer: number): ()
    local on_floor = t.item_at(HOLDER_X, ENGINEER_Y, "welder")
    bench.pick_up_here(engineer, "welder")
    if on_floor == nil or on_floor.state ~= "lit" then
        t.use_self(engineer)
        t.run_ticks(2)
    end
end

-- Pushes the occupant against the shell and returns the tick the wait began.
function bench.push_and_start(occupant: number): number
    t.move(occupant, "north")
    t.run_ticks(2)
    assert(bench.heard_count(occupant, "start forcing your way out") >= 1, "the occupant hears the push begin")
    return t.now()
end

function bench.run_until(tick: number): ()
    local remaining = tick - t.now()
    assert(remaining >= 0, "the spec has not run past tick " .. tick)
    if remaining > 0 then
        t.run_ticks(remaining)
    end
end

-- The seq of the last `latch_set` row that switched `latch` to `on`, or nil.
function bench.last_latch_seq(latch: string, on: boolean): number?
    local found: number? = nil
    for _, row in ipairs(t.ledger_rows("latch_set")) do
        if row.latch == latch and row.on == on then
            found = row.seq
        end
    end
    return found
end

function bench.last_open_seq(): number
    local opened = t.ledger_rows("container_opened")
    return opened[#opened].seq
end

-- A pack row's declared field (`sim.ledger.record` fields).
function bench.field(row: SpecLedgerRow, name: string): unknown
    return (row.fields :: { [string]: unknown })[name]
end

-- The body a script-attributed row was triggered by.
function bench.triggered_by(row: SpecLedgerRow): unknown
    return (row.actor :: { [string]: unknown }).triggered_by
end

return bench

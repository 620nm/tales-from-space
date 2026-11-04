-- A flight of stairs facing east (content/structures/stairs/stairs.luau; tg
-- stairs.dm): leaving it east climbs to the landing one level up, stepping
-- back onto its top walks down onto it, a step onto it from the landing's
-- side is refused, an open landing refuses the climb, a one-level fall onto
-- it is caught (content/lib/fall.luau), a tumble rolls the body off and
-- staggers its next steps, a pulled crate follows up it, an item it catches
-- lands without a line and a body pulled as it falls onto it does not tumble.
-- `t.target_at` with no level offset names the viewer's own level.
local FLIGHT = { x = 3, y = 2 }
local LANDING = { x = 4, y = 2 }
local UPPER = 1
local DOWN_STAIRS = "You fall down the stairs!"
local CRASHES = "wrench crashes into the floor!"

t.set_breathing(false)
t.world_file("stairwell.ron", 0)
local p = t.join()
t.run_ticks(4)

type Direction = "north" | "south" | "east" | "west"

local function walk(who: number, directions: { Direction })
    for _, direction in ipairs(directions) do
        t.move(who, direction)
        t.run_seconds(1)
    end
end

local function step(direction: Direction)
    walk(p, { direction })
end

local function assert_at(x: number, y: number, why: string)
    local px, py = t.pos(p)
    assert(px == x and py == y, why .. ": expected (" .. x .. ", " .. y .. "), got (" .. px .. ", " .. py .. ")")
end

local function assert_level(upper: boolean, why: string)
    assert((t.target_at(p, 7, 3, "wrench") ~= nil) == upper, why .. ": the upper wrench")
    assert((t.target_at(p, 1, 1, "wrench") ~= nil) == not upper, why .. ": the lower wrench")
end

local function assert_moves(count: number, via: string, why: string)
    local rows = t.ledger_rows("level_changed")
    assert(#rows == count, why .. ": expected " .. count .. " level changes, got " .. #rows)
    local last = rows[count]
    assert(last.via == via and last.levels == 1, why .. ": one level via " .. via .. ", got " .. tostring(last.via))
end

local function heard_by(who: number): string
    return table.concat(t.messages(who), " | ")
end

local function heard(): string
    return heard_by(p)
end

local function pick_up_wrench(x: number, y: number)
    local wrench = assert(t.target_at(p, x, y, "wrench"), "a wrench to pick up")
    t.click(p, x, y, wrench)
    t.run_ticks(2)
    assert(t.hands(p).held == "wrench", "the wrench is in hand")
end

assert_at(2, 2, "the body spawns at the foot of the flight")
assert_level(false, "level zero")

-- 1. Up: onto the flight, then off it east to the landing a level up.
step("east")
assert_at(FLIGHT.x, FLIGHT.y, "onto the flight on its own level")
assert_level(false, "on the flight")
step("east")
assert_at(LANDING.x, LANDING.y, "the climb lands one tile ahead")
assert_level(true, "after climbing")
assert_moves(1, "link", "the climb")

-- 2. Down: west onto the top walks down onto the flight under it.
step("west")
assert_at(FLIGHT.x, FLIGHT.y, "the descent keeps the column")
assert_level(false, "after descending")
assert_moves(2, "link", "the descent")

-- 3. Block: from under the landing, west into the flight is refused.
step("south")
step("east")
step("north")
assert_at(LANDING.x, LANDING.y, "under the landing on level zero")
step("west")
assert_at(LANDING.x, LANDING.y, "the flight refuses a step from ahead")
assert(#t.ledger_rows("level_changed") == 2, "the block changes no level")
assert(#t.ledger_rows("level_step_refused") == 0, "a block writes no refusal row")

-- 4. An open landing refuses the climb.
assert(t.set_composition(LANDING.x, LANDING.y, "open", UPPER), "the landing is cut open")
step("south")
step("west")
step("north")
assert_at(FLIGHT.x, FLIGHT.y, "back on the flight from the south")
step("east")
assert_at(FLIGHT.x, FLIGHT.y, "the open landing refuses the climb")
assert_level(false, "after the refusal")
assert(#t.ledger_rows("level_changed") == 2, "the refusal changes no level")
local refused = t.ledger_rows("level_step_refused")
assert(#refused == 1, "one refusal row, got " .. #refused)
assert(refused[1].reason == "landing_open" and refused[1].via == "link", "refused landing_open via link")
assert(t.set_composition(LANDING.x, LANDING.y, "floor", UPPER), "the landing is floored again")

-- 5. A one-level fall onto the flight is caught: a body awake lands quietly.
step("east")
assert_moves(3, "link", "the second climb")
step("north")
step("west")
local _ = heard()
step("south")
t.run_seconds(1)
assert_at(FLIGHT.x, FLIGHT.y, "the fall lands on the flight under the top")
assert_level(false, "after the fall")
assert_moves(4, "fall", "the fall")
assert(not heard():find(DOWN_STAIRS, 1, true), "a body awake does not tumble")

-- 6. A body out cold that falls onto the flight tumbles down it.
step("east")
assert_moves(5, "link", "the third climb")
assert(t.set_composition(FLIGHT.x, FLIGHT.y, "floor", UPPER), "the top is floored over")
step("north")
step("west")
step("south")
assert_at(FLIGHT.x, FLIGHT.y, "standing on the floored top")
assert_level(true, "on the floored top")
t.set_health(p, { oxy = 60 })
assert(not assert(t.body(p)).conscious, "the body is out cold")
local before = t.health(p).health
local _ = heard()
assert(t.set_composition(FLIGHT.x, FLIGHT.y, "open", UPPER), "the floor opens under the body")
-- Only until the tumble, so its stagger has not yet run out (6b).
local tumble_heard = ""
for _ = 1, 40 do
    t.tick()
    tumble_heard ..= heard()
    if tumble_heard:find(DOWN_STAIRS, 1, true) then
        break
    end
end
assert_at(FLIGHT.x, FLIGHT.y, "the body fell onto the flight")
assert_moves(6, "fall", "the second fall")
assert(tumble_heard:find(DOWN_STAIRS, 1, true), "the sleeper falls down the stairs")
assert(before - t.health(p).health >= 4, "the tumble bruises")

-- 6a. The tumble rolls the body away from the foot (stairs.dm:353): a step
-- west every 0.4 s for 1 s; the crate at (1, 2) stops the second.
t.run_ticks(17)
assert_at(2, 2, "the tumble rolls the body a tile off the flight")
assert(#t.ledger_rows("level_changed") == 6, "the roll changes no level")
local roll_refusals = t.ledger_rows("entity_step_refused")
assert(
    #roll_refusals == 1 and roll_refusals[1].reason == "blocked" and roll_refusals[1].toward == "West",
    "the crate refuses the second step, and the refusal is the script's"
)

-- 6b. The tumble staggers for 2 s (stairs.dm:349): stood up at once, each
-- step costs 0.085 s more (lib/fall.luau), 4 ticks at 20 Hz becoming 6.
assert(t.staff_restore(p), "staff stands the tumbled body up")
local function landing_ticks(direction: Direction, count: number): { number }
    local landed: { number } = {}
    local x, y = t.pos(p)
    for tick = 1, 40 do
        t.move(p, direction)
        t.tick()
        local nx, ny = t.pos(p)
        if nx ~= x or ny ~= y then
            table.insert(landed, tick)
            x, y = nx, ny
            if #landed == count then
                return landed
            end
        end
    end
    error("fewer than " .. count .. " landings holding " .. direction)
end
local _ = landing_ticks("south", 1)
local staggered = landing_ticks("east", 2)
t.run_seconds(2)
local steady = landing_ticks("east", 2)
assert_at(6, 3, "walked east along the south row")
local staggered_gap = staggered[2] - staggered[1]
local steady_gap = steady[2] - steady[1]
assert(staggered_gap > steady_gap, "a staggered step is slower: " .. staggered_gap .. " ticks against " .. steady_gap)
walk(p, { "west", "west", "west", "north" })
assert_at(FLIGHT.x, FLIGHT.y, "back on the flight")
t.set_health(p, { oxy = 0, brute = 0 })
t.run_seconds(6)
assert_level(false, "awake at the foot")

-- 7. Pull: a crate towed onto the flight follows up the climb.
step("west")
assert_at(2, 2, "beside the crate")
local crate = assert(t.target_at(p, 1, 2, "crate"), "the crate waits at the foot")
t.pull(p, 1, 2, crate)
t.tick()
step("east")
step("east")
assert_at(LANDING.x, LANDING.y, "the puller climbs")
assert_moves(7, "link", "the puller's climb")
step("east")
assert_at(LANDING.x + 1, LANDING.y, "the puller walks on")
assert_moves(8, "link", "the crate's climb")
assert(t.same_target(assert(t.target_at(p, LANDING.x, LANDING.y, "crate")), crate), "the crate followed up")

-- 8. An item lands with a line on a floor, and without one on a flight that
-- catches it (intercept_zImpact's FALL_NO_MESSAGE, stairs.dm:334).
walk(p, { "east", "east", "south" })
t.stop_pull(p)
assert_at(7, 3, "on the upper wrench, the crate parked north of it")
pick_up_wrench(7, 3)
assert(t.set_composition(6, 3, "open", UPPER), "a hole beside the wrench")
local _ = heard()
t.throw(p, 6, 3)
t.run_seconds(2)
assert(heard():find(CRASHES, 1, true), "a wrench landing on the floor crashes")
assert(t.set_composition(6, 3, "floor", UPPER), "the hole is floored again")
walk(p, { "west", "west", "west", "north", "west", "west", "north" })
assert_at(2, 1, "beside the lower wrench")
pick_up_wrench(1, 1)
walk(p, { "south", "east", "east" })
assert_at(LANDING.x, LANDING.y, "back up on the landing")
t.throw(p, FLIGHT.x, FLIGHT.y)
t.run_seconds(2)
assert(t.hands(p).held == nil, "the wrench left the hand")
assert(not heard():find(CRASHES, 1, true), "the flight catches the wrench without a line")

-- 9. A body out cold pulled as it falls onto the flight does not tumble
-- (`can_fall_down_stairs`, stairs.dm:338).
walk(p, { "north", "west", "west", "south" })
assert_at(2, 2, "upstairs beside the top")
local sleeper = t.join()
t.run_ticks(4)
walk(sleeper, { "east", "east" })
assert(t.set_composition(FLIGHT.x, FLIGHT.y, "floor", UPPER), "the top is floored over again")
walk(sleeper, { "north", "west", "south" })
local sx, sy = t.pos(sleeper)
assert(sx == FLIGHT.x and sy == FLIGHT.y, "the sleeper stands on the floored top")
t.pull(p, FLIGHT.x, FLIGHT.y, t.body_target(p, sleeper))
t.tick()
t.set_health(sleeper, { oxy = 60 })
assert(not assert(t.body(sleeper)).conscious, "the sleeper is out cold")
local falls_before = #t.ledger_rows("level_changed")
local _ = heard_by(sleeper)
assert(t.set_composition(FLIGHT.x, FLIGHT.y, "open", UPPER), "the floor opens under the sleeper")
t.run_seconds(2)
local rows = t.ledger_rows("level_changed")
assert(#rows > falls_before and rows[#rows].via == "fall", "the pulled sleeper fell")
assert(not heard_by(sleeper):find(DOWN_STAIRS, 1, true), "a body pulled as it fell does not tumble")

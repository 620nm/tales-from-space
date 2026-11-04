-- A flight of stairs facing east (content/structures/stairs/stairs.luau; tg
-- stairs.dm): leaving it east climbs to the landing one level up, stepping
-- back onto its top walks down onto it, a step onto it from the landing's
-- side is refused, an open landing refuses the climb, a one-level fall onto
-- it is caught (content/lib/fall.luau) and a pulled crate follows up it.
-- `t.target_at` names only the viewer's own level.
local FLIGHT = { x = 3, y = 2 }
local LANDING = { x = 4, y = 2 }
local UPPER = 1
local DOWN_STAIRS = "You fall down the stairs!"

t.set_breathing(false)
t.world_file("stairwell.ron", 0)
local p = t.join()
t.run_ticks(4)

local function step(direction: "north" | "south" | "east" | "west")
    t.move(p, direction)
    t.run_seconds(1)
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

local function heard(): string
    return table.concat(t.messages(p), " | ")
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
t.run_seconds(2)
assert_at(FLIGHT.x, FLIGHT.y, "the body fell onto the flight")
assert_moves(6, "fall", "the second fall")
assert(heard():find(DOWN_STAIRS, 1, true), "the sleeper falls down the stairs")
assert(before - t.health(p).health >= 4, "the tumble bruises")
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

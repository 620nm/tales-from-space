-- A flight of stairs climbs a body to the top of the stairs on the level above
-- and back down (content/compositions.luau; tg stairs.dm:274-283,324-334). A
-- stair with no top over it refuses the step, as tg's needs open space above
-- (stairs.dm:11). `t.target_at` names only the viewer's own level.
local STAIRS = { x = 3, y = 2 }
local UPPER = 1

t.world_file("stairwell.ron", 0)
local p = t.join()
t.run_ticks(4)

local function assert_at(x: number, y: number, why: string)
    local px, py = t.pos(p)
    assert(px == x and py == y, why .. ": expected (" .. x .. ", " .. y .. "), got (" .. px .. ", " .. py .. ")")
end

local function assert_level(upper: boolean, why: string)
    assert((t.target_at(p, 5, 3, "wrench") ~= nil) == upper, why .. ": the upper wrench")
    assert((t.target_at(p, 1, 1, "wrench") ~= nil) == not upper, why .. ": the lower wrench")
end

assert_at(1, 2, "the body spawns on level zero")
assert_level(false, "level zero")

-- 1. Up: stepping onto the stairs climbs to the top of the stairs over them.
t.move(p, "east")
t.run_seconds(1)
t.move(p, "east")
t.run_seconds(1)
assert_at(STAIRS.x, STAIRS.y, "the climb keeps the column")
assert_level(true, "after climbing")
local rows = t.ledger_rows("level_changed")
assert(#rows == 1 and rows[1].via == "climb" and rows[1].levels == 1, "one climb row, got " .. #rows)

-- 2. Down: off the top, then back onto it, lands on the stairs below.
t.move(p, "east")
t.run_seconds(1)
assert_at(STAIRS.x + 1, STAIRS.y, "walked off the top on level one")
assert_level(true, "beside the top")
t.move(p, "west")
t.run_seconds(1)
assert_at(STAIRS.x, STAIRS.y, "the descent keeps the column")
assert_level(false, "after descending")
rows = t.ledger_rows("level_changed")
assert(#rows == 2 and rows[2].via == "climb", "a second climb row, got " .. #rows)

-- 3. A stair with a floor over it is no way up: the step is refused.
t.move(p, "west")
t.run_seconds(1)
assert_at(STAIRS.x - 1, STAIRS.y, "walked off the stairs on level zero")
assert(t.set_composition(STAIRS.x, STAIRS.y, "floor", UPPER), "the top is floored over")
t.move(p, "east")
t.run_seconds(1)
assert_at(STAIRS.x - 1, STAIRS.y, "the unpaired stair refuses the step")
assert_level(false, "after the refusal")
assert(#t.ledger_rows("level_changed") == 2, "the refusal changes no level")
local refused = t.ledger_rows("level_step_refused")
assert(#refused == 1 and refused[1].reason == "unpaired", "one unpaired refusal, got " .. #refused)

-- Standing on a flight shows the landing ahead (`view_landing` on the
-- stairs' rising link, content/structures/stairs/stairs.luau): the upper
-- tiles past the flight's front edge are disclosed, the ones behind it never
-- are, and stepping off withdraws them. The pack answers the flight's reach
-- `allowed` and a hole's not (content/lib/level_crossing.luau); a hand claim
-- on the landing is not specced: `t.target_at` names only the viewer's level.
local FOOT = { x = 2, y = 2 }
local FLIGHT = { x = 3, y = 2 }
local LANDING = { x = 4, y = 2 }
local UPPER = 1

t.set_breathing(false)
t.world_file("stairwell.ron", 0)
local p = t.join()
t.run_ticks(4)

local function assert_at(x: number, y: number, why: string)
    local px, py = t.pos(p)
    assert(px == x and py == y, ("%s: expected (%d, %d), got (%d, %d)"):format(why, x, y, px, py))
end

local function seen_upper(x: number, y: number): boolean
    return #t.seen_composition(p, x, y, UPPER) > 0
end

assert_at(FOOT.x, FOOT.y, "the body spawns at the foot of the flight")
assert(not seen_upper(LANDING.x, LANDING.y), "the foot does not see the landing")

t.move(p, "east")
t.run_seconds(1)
assert_at(FLIGHT.x, FLIGHT.y, "onto the flight on its own level")
assert(#t.ledger_rows("level_changed") == 0, "the flight is still level zero")
assert(seen_upper(LANDING.x, LANDING.y), "the flight shows the landing ahead")
assert(seen_upper(LANDING.x, LANDING.y - 1), "and the tile beside the landing, past the edge")
assert(not seen_upper(FOOT.x, FOOT.y), "the upper tile behind the flight is never sent")
assert(not seen_upper(FLIGHT.x, FLIGHT.y + 1), "nor the one beside the flight")

t.move(p, "west")
t.run_seconds(1)
assert_at(FOOT.x, FOOT.y, "back off the flight")
assert(not seen_upper(LANDING.x, LANDING.y), "stepping off withdraws the landing")
assert(#t.script_errors() == 0, "the flight's handlers run cleanly")

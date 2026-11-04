-- Standing on a flight shows the landing ahead (`view_landing` on the
-- stairs' rising link, content/structures/stairs/stairs.luau): the upper
-- tiles past the flight's front edge are disclosed, the ones behind it never
-- are, and stepping off withdraws them. What the flight shows is in reach,
-- since the pack allows a reach on another level only via a link
-- (content/lib/level_crossing.luau): a wrench past the edge is picked up, a
-- crate on the landing is pulled down onto the flight, and a hand through a
-- hole is refused.
local FOOT = { x = 2, y = 2 }
local FLIGHT = { x = 3, y = 2 }
local LANDING = { x = 4, y = 2 }
local HOLE = { x = 6, y = 2 }
local UPPER = 1

type Direction = "north" | "south" | "east" | "west"

t.set_breathing(false)
t.world_file("stairwell.ron", 0)
local p = t.join()
t.run_ticks(4)

local function assert_at(who: number, x: number, y: number, why: string)
    local px, py = t.pos(who)
    assert(px == x and py == y, ("%s: expected (%d, %d), got (%d, %d)"):format(why, x, y, px, py))
end

local function step(who: number, direction: Direction)
    t.move(who, direction)
    t.run_seconds(1)
end

local function seen_upper(x: number, y: number): boolean
    return #t.seen_composition(p, x, y, UPPER) > 0
end

assert_at(p, FOOT.x, FOOT.y, "the body spawns at the foot of the flight")
assert(not seen_upper(LANDING.x, LANDING.y), "the foot does not see the landing")

step(p, "east")
assert_at(p, FLIGHT.x, FLIGHT.y, "onto the flight on its own level")
assert(#t.ledger_rows("level_changed") == 0, "the flight is still level zero")
assert(seen_upper(LANDING.x, LANDING.y), "the flight shows the landing ahead")
assert(seen_upper(LANDING.x, LANDING.y - 1), "and the tile beside the landing, past the edge")
assert(not seen_upper(FOOT.x, FOOT.y), "the upper tile behind the flight is never sent")
assert(not seen_upper(FLIGHT.x, FLIGHT.y + 1), "nor the one beside the flight")

step(p, "west")
assert_at(p, FOOT.x, FOOT.y, "back off the flight")
assert(not seen_upper(LANDING.x, LANDING.y), "stepping off withdraws the landing")

-- ---- reach from the flight, and none through a hole -----------------
-- The same flight, a crate on its landing and a wrench past its edge; a
-- second body upstairs beside a hole over a wrench on level zero.
t.world(
    [==[(
    name: "flight reach",
    environment: (kind: Exact(space), gravity_m_s2: Exact(9.80665)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (substrate: Open)),
    },
    levels: [
        (
            rows: [
                "#########",
                "#.......#",
                "#.......#",
                "#.......#",
                "#########",
            ],
            structures: [
                (2, 2, "player_spawn", { "jobs": "engineer" }),
                (3, 2, "stairs", { "dir": "east" }),
            ],
            items: [(6, 2, "wrench")],
        ),
        (
            rows: [
                "#########",
                "#.......#",
                "#..o..o.#",
                "#.......#",
                "#########",
            ],
            structures: [(5, 2, "player_spawn", { "jobs": "medic" }), (4, 2, "crate")],
            items: [(4, 1, "wrench")],
        ),
    ],
)]==],
    0,
    "free_build"
)
local climber = t.join("engineer")
local leaner = t.join("medic")
t.run_ticks(4)
assert_at(climber, FOOT.x, FOOT.y, "the climber stands at the foot")
assert_at(leaner, HOLE.x - 1, HOLE.y, "the leaner stands upstairs beside the hole")

-- A wrench past the front edge, a level up, comes to hand from the flight.
step(climber, "east")
assert_at(climber, FLIGHT.x, FLIGHT.y, "the climber is on the flight")
local AHEAD = { x = LANDING.x, y = LANDING.y - 1 }
local wrench = assert(t.target_at(climber, AHEAD.x, AHEAD.y, "wrench", 1), "the wrench ahead")
t.click(climber, AHEAD.x, AHEAD.y, wrench)
t.run_ticks(2)
assert(t.hands(climber).held == "wrench", "the wrench a level up is picked up from the flight")
t.drop(climber)
t.run_ticks(2)

-- The crate on the landing is pulled; stepping back off the flight trails
-- it onto the top, whose link carries it down onto the flight.
local crate = assert(t.target_at(climber, LANDING.x, LANDING.y, "crate", 1), "the landing's crate")
t.pull(climber, LANDING.x, LANDING.y, crate)
t.tick()
step(climber, "west")
assert_at(climber, FOOT.x, FOOT.y, "the climber steps back to the foot")
local below = t.target_at(climber, FLIGHT.x, FLIGHT.y, "crate")
assert(below ~= nil and t.same_target(below, crate), "the crate came down onto the flight")
assert(t.target_at(climber, LANDING.x, LANDING.y, "crate", 1) == nil, "and left the landing")
t.stop_pull(climber)

-- A hand through a hole is not via a link: the pack refuses it, and the
-- refusal is rowed.
local refused_before = #t.ledger_rows("claim_refused")
local deep = assert(t.target_at(leaner, HOLE.x, HOLE.y, "wrench", -1), "the wrench below the hole")
t.click(leaner, HOLE.x, HOLE.y, deep)
t.run_ticks(2)
assert(t.hands(leaner).held == nil, "the wrench below the hole is out of reach")
local refusals = t.ledger_rows("claim_refused")
assert(#refusals > refused_before, "the refused reach is rowed")
local why = refusals[#refusals].why
assert(why == "off_level_reach", "as off-level reach: " .. tostring(why))
assert(#t.script_errors() == 0, "the flight's handlers run cleanly")

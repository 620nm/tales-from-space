-- The smallest station the editor palette can build — a sealed room
-- from composition presets with one airlock, one light and one spawn
-- point — drops one player in and keeps them alive in both modes.
-- This is the playtest contract for a freshly built map: spawn,
-- breathe, and get through your own door without any power or air
-- machinery placed yet.
local MAP = [==[(
    name: "editor starter room",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "#########",
                "#......##",
                "#........",
                "#......##",
                "#########",
            ],
            structures: [(1, 2, "player_spawn"), (7, 2, "airlock"), (3, 2, "light")],
        ),
    ],
)]==]

local function walk_east(p: number, goal_x: number): number
    local steps = 0
    local x = t.pos(p)
    while x ~= goal_x and steps <= 24 do
        steps += 1
        t.move(p, "east")
        t.run_ticks(5) -- a step is rate-limited; give the cooldown room
        x = t.pos(p)
    end
    return x
end

-- Free Build is the drop-in mode: connect and stand in the room.
t.world(MAP, 7, "free_build")
local builder = t.join()
t.tick()
assert(t.pos(builder) == 1, "the builder spawns at the placed spawn point")
t.run_seconds(30)
local body = assert(t.body(builder), "the builder has a body")
assert(body.animate, "and is still standing after half a minute in the sealed room")
assert(body.health >= 99, "and unharmed by its air, health " .. tostring(body.health))

-- The airlock has no power yet, so it will not bump open; the belt
-- the mode issued carries the tool that opens it by hand.
assert(walk_east(builder, 6) == 6, "the builder reaches the airlock")
t.move(builder, "east")
t.run_ticks(5)
assert(t.pos(builder) == 6, "but an unpowered airlock does not bump open")
assert(not assert(t.door_at(7, 2)).open, "and the leaf stays shut")
assert(not assert(t.door_at(7, 2)).powered, "no grid feeds the leaf")
t.take_from(builder, "belt", 4) -- screwdriver, wrench, welder, crowbar
t.tick()
assert(t.hands(builder).held == "crowbar", "the crowbar comes off the belt")
t.click(builder, 7, 2, assert(t.target_at(builder, 7, 2)))
for _ = 1, 120 do -- the 2.5 s pry plus its swing, polled (20 ticks a second)
    if assert(t.door_at(7, 2)).open then
        break
    end
    t.run_ticks(1)
end
assert(
    assert(t.door_at(7, 2)).open,
    "pried open by hand; messages: " .. table.concat(t.messages(builder), " | ")
)
assert(walk_east(builder, 8) == 8, "and the builder walks out through it")

-- Space Station reaches the same room through preparation: one
-- ready player, the countdown, then admission at the spawn point.
t.world(MAP, 7, "space_station")
local crew = t.connect()
t.prepare(crew, { name = "Solo Tester", ranked_jobs = { "assistant" }, fallback = false })
t.ready(crew)
t.preparation_steps(120 * t.tick_hz())
assert(t.round_status().phase == "playing", "the solo cohort starts the round")
local joined = t.ledger_rows("joined_job")
assert(#joined == 1 and joined[1].job == "assistant", "the solo tester is admitted as assistant")
t.run_seconds(10)
local crew_body = assert(t.body(crew), "the admitted tester has a body")
assert(crew_body.animate, "and is standing in the starter room")
assert(crew_body.health >= 99, "and unharmed by its air, health " .. tostring(crew_body.health))

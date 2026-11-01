-- The pack's `move.brace` (content/lib/brace.luau) in an explicit microgravity
-- sky: a solid thing braces a conscious body only on its own level, and only
-- when it is anchored. Every other way a flight ends is a collision.
local function weightless(below: string, rows: string, structures: string): number
    t.world(
        string.format(
            [==[(
                name: "brace",
                tags: ["space"],
                levels_below_ground: %s,
                environment: (kind: Exact(space), gravity_m_s2: Exact(0.0)),
                legend: {
                    's': (composition: (substrate: Named("space"))),
                    'f': (composition: (substrate: Named("space"), components: [(component: "station_base")])),
                    'w': (composition: (substrate: Named("space"), components: [(component: "wall")])),
                    'r': (composition: (components: [(component: "rock")])),
                },
                levels: [%s(rows: [%s], structures: [%s])],
            )]==],
            if below == "" then "0" else "1",
            below,
            rows,
            structures
        ),
        0,
        "free_build"
    )
    local player = t.join()
    t.run_ticks(2)
    return player
end

local ROCK_BELOW = [[(rows: ["rrrrrrr", "rrrrrrr", "rrrrrrr"], structures: []),]]
local OPEN_ROWS = [["sssssss", "sssfsss", "sssssss"]]

local floating = weightless(ROCK_BELOW, OPEN_ROWS, [[(3, 1, "player_spawn")]])
t.move(floating, "east")
t.run_seconds(0.5)
local x, y = t.pos(floating)
assert(x == 3 and y == 1, "rock a level down braces nothing: " .. x .. "," .. y)

-- A launch off the wall at (1, 2), along row 2, past whatever stands at (6, 1).
local RUN_ROWS = [["sssssssss", "ssssssXss", "swfssssss", "sssssssss"]]

local function launched(beside: string, structures: string): number
    local rows = string.gsub(RUN_ROWS, "X", beside)
    local player = weightless("", rows, [[(2, 2, "player_spawn")]] .. structures)
    t.move(player, "east")
    t.tick()
    local x, y = t.pos(player)
    assert(x == 3 and y == 2, "the wall launched the body: " .. x .. "," .. y)
    return player
end

local caught = launched("w", "")
t.run_seconds(4)
local caught_x = t.pos(caught)
assert(caught_x == 5, "a wall beside the path ends the flight: " .. caught_x)

local past_loose = launched("s", [[, (6, 1, "canister")]])
t.run_seconds(4)
local past_loose_x = t.pos(past_loose)
assert(past_loose_x == 8, "a loose canister beside the path braces nothing: " .. past_loose_x)

local corpse = launched("w", "")
assert(t.staff_kill(corpse), "the staff action kills the body")
t.run_seconds(4)
local corpse_x = t.pos(corpse)
assert(corpse_x == 8, "a corpse grips nothing and coasts to the edge: " .. corpse_x)

local sleeper = launched("w", "")
t.set_health(sleeper, { oxy = 60 })
assert(not assert(t.body(sleeper)).conscious, "past fifty the body is out cold")
t.run_seconds(4)
local sleeper_x = t.pos(sleeper)
assert(sleeper_x == 8, "a sleeper grips nothing and coasts to the edge: " .. sleeper_x)

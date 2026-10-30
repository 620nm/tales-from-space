local bench = require("@helpers/grav_bench")

-- Alt+click turns a bolted-down emitter or ring, and a loose ring waits
-- for its bolts: an emitter turns in both states, a ring only once it is
-- anchored (a loose ring is a cart and shows no facing). Each accepted
-- quarter-turn is a ledger row; a refused one writes none.

bench.world(
    '(5, 4, "player_spawn"), ' .. bench.part_rows({ ne = { state = "displaced" } }),
    '(5, 4, "wrench")'
)
local p = t.join()
t.tick()

local function sprite(x: number, y: number): string
    return tostring(assert(t.structure_at(x, y)).sprite)
end

local function turn(x: number, y: number, id: string, clockwise: boolean)
    t.rotate(p, x, y, assert(t.target_at(p, x, y, id)), clockwise)
    t.tick()
end

-- A bolted-down emitter turns, both ways, through the declared facings.
assert(sprite(5, 3) == "grav_emitter_south", "the north emitter points south: " .. sprite(5, 3))
turn(5, 3, "grav_emitter", true)
assert(sprite(5, 3) == "grav_emitter_west", "clockwise from south is west: " .. sprite(5, 3))
turn(5, 3, "grav_emitter", false)
assert(sprite(5, 3) == "grav_emitter_south", "and back again: " .. sprite(5, 3))

-- A bolted-down ring turns to the next corner arc.
assert(
    sprite(4, 3) == "grav_supermagnet_north",
    "the north-west ring wears its arc: " .. sprite(4, 3)
)
turn(4, 3, "grav_supermagnet", true)
assert(sprite(4, 3) == "grav_supermagnet_east", "one turn clockwise: " .. sprite(4, 3))
assert(#t.ledger_rows("Rotated") == 3, "every accepted quarter-turn is recorded")

-- A loose ring does not turn.
turn(6, 3, "grav_supermagnet", true)
assert(#t.ledger_rows("Rotated") == 3, "a refused turn writes no row")

-- Bolted down, it does.
bench.hold(p, "wrench", { { 5, 4 } })
t.click(p, 6, 3, t.target_at(p, 6, 3, "grav_supermagnet"))
t.run_seconds(1.5)
assert(sprite(6, 3) == "grav_supermagnet_east", "bolted down, it wears its arc: " .. sprite(6, 3))
turn(6, 3, "grav_supermagnet", true)
assert(sprite(6, 3) == "grav_supermagnet_south", "and now it turns: " .. sprite(6, 3))
assert(#t.ledger_rows("Rotated") == 4, "the fourth accepted turn is recorded")

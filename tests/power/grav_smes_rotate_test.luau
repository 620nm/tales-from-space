local bench = require("@helpers/grav_bench")

-- Alt+click turns an emitter in both states; a ring never turns, set or
-- packed, because its corner comes from the emitters beside it. Each
-- accepted quarter-turn is a ledger row; a refused one writes none.

bench.world('(5, 4, "player_spawn"), ' .. bench.part_rows({ ne = { packed = true } }), "")
local p = t.join()
t.tick()

local function sprite(x: number, y: number): string
    return tostring(assert(t.structure_at(x, y)).sprite)
end

local function turn(x: number, y: number, id: string, clockwise: boolean)
    t.rotate(p, x, y, assert(t.target_at(p, x, y, id)), clockwise)
    t.tick()
end

-- A bolted-down emitter turns through the declared facings. The pointer
-- turns clockwise only, so three more quarter-turns bring it home.
assert(sprite(5, 3) == "grav_emitter_south", "the north emitter points south: " .. sprite(5, 3))
turn(5, 3, "grav_emitter", true)
assert(sprite(5, 3) == "grav_emitter_west", "clockwise from south is west: " .. sprite(5, 3))
for _ = 1, 3 do
    turn(5, 3, "grav_emitter", true)
end
assert(sprite(5, 3) == "grav_emitter_south", "and round again: " .. sprite(5, 3))

-- A set ring wears its arc and stays there.
assert(
    sprite(4, 3) == "grav_supermagnet_ring_north",
    "the north-west ring wears its arc: " .. sprite(4, 3)
)
turn(4, 3, "grav_supermagnet_ring", true)
assert(sprite(4, 3) == "grav_supermagnet_ring_north", "a set ring does not turn: " .. sprite(4, 3))

-- Nor does a packed one.
turn(6, 3, "grav_supermagnet", true)
assert(sprite(6, 3) == "grav_supermagnet_loose", "the cart shows no facing: " .. sprite(6, 3))
assert(#t.ledger_rows("Rotated") == 4, "a refused turn writes no row")

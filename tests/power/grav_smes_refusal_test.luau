local bench = require("@helpers/grav_bench")

-- The weld says what is wrong, in words naming the position, and takes
-- nothing apart while it refuses. One room, mended defect by defect from
-- the centre tile (the only tile that reaches every part): an unlit torch,
-- an emitter facing away, an unbolted emitter, a ring still packed, a ring
-- set the wrong way round, and finally a ring that is simply not there.

bench.world(
    '(5, 4, "player_spawn"), '
        .. bench.part_rows({
            e = { dir = "east" },
            w = { state = "displaced" },
            ne = { packed = true },
            se = { dir = "north" },
            sw = { absent = true },
        }),
    '(5, 4, "welder"), (5, 4, "wrench")'
)
local p = t.join()
t.tick()

local NEAR = { { 5, 4 } }
local SOUTH_EMITTER = { 5, 5 }

-- Click the south emitter with the torch and report what the player heard.
local function weld_says(line: string)
    local _ = t.messages(p)
    local x, y = SOUTH_EMITTER[1], SOUTH_EMITTER[2]
    t.click(p, x, y, t.target_at(p, x, y, "grav_emitter"))
    t.run_ticks(4)
    assert(bench.told(p, line), "the torch should say: " .. line)
    assert(t.structure_at(5, 4) == nil, "and nothing was welded")
end

-- Click a part with the wrench held and wait out the bolts.
local function wrench(x: number, y: number, id: string)
    bench.hold(p, "wrench", NEAR)
    t.click(p, x, y, t.target_at(p, x, y, id))
    t.run_seconds(1.5)
end

local function turn(x: number, y: number, id: string, quarter_turns: number)
    for _ = 1, quarter_turns do
        t.rotate(p, x, y, assert(t.target_at(p, x, y, id)), true)
    end
end

-- A torch that is not lit welds nothing.
bench.hold(p, "welder", NEAR)
weld_says("Light the welding tool first.")
t.use_self(p)
t.run_ticks(2)

-- Wrong facing: an emitter pointing away from the centre.
weld_says("The east emitter must face the centre.")
turn(6, 4, "grav_emitter", 2)

-- Unanchored emitter: wears its loose picture until bolted down.
assert(
    assert(t.structure_at(4, 4)).sprite == "grav_emitter_east",
    "loose west emitter wears its unbolted picture"
)
bench.hold(p, "welder", NEAR)
weld_says("The west emitter must be bolted down.")
-- The loose part itself answers too.
local _ = t.messages(p)
t.click(p, 4, 4, t.target_at(p, 4, 4, "grav_emitter"))
t.run_ticks(4)
assert(bench.told(p, "The west emitter must be bolted down."), "the loose part says why")
wrench(4, 4, "grav_emitter")
assert(
    assert(t.structure_at(4, 4)).sprite == "grav_emitter_anchored_east",
    "bolted west emitter wears its anchored picture"
)
assert(
    assert(t.structure_at(5, 5)).sprite == "grav_emitter_anchored_north",
    "bolted south emitter wears anchored_south (grav_emitter_anchored_north)"
)

-- A ring still on its cart.
bench.hold(p, "welder", NEAR)
weld_says("The north-east supermagnet must be bolted down.")
wrench(6, 3, "grav_supermagnet")

-- A ring set the wrong way round: packing it up and setting it again finds
-- its corner.
bench.hold(p, "welder", NEAR)
weld_says("The south-east supermagnet sits the wrong way round; pack it up and set it again.")
wrench(6, 5, "grav_supermagnet_ring")
wrench(6, 5, "grav_supermagnet")

-- Everything standing is right now; the last ring is just not there.
bench.hold(p, "welder", NEAR)
weld_says("The south-west supermagnet is missing.")
bench.assert_standing({ "n", "e", "s", "w", "nw", "ne", "se" })

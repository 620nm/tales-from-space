local network_channels = require("@helpers/network_channels")

-- Network instances retain their channel and facing while connections
-- determine the picture disclosed to each player. These specs exercise
-- the live adjacency calculation through t.network_joined; each branch
-- must connect in both directions before the shared edge appears.
-- Artwork belongs to the pack's per-channel shape tables. Raw lengths
-- remain network instances, so entity-only t.layers has no pipe row.

-- BYOND's direction bits, which the art is named for.
local N, S, E, W = 1, 2, 4, 8

-- The shape the client will draw here: `t.network_joined`, the engine's
-- own `joined_dirs` fed from live state. A bit comes back only when
-- three things hold at once -- the neighbour carries this layer, this
-- length reaches toward it, and it reaches back (tg's
-- `connection_check`, both ends asked at once). Paint and component
-- ports are in the derivation too; neither is in play on any map below
-- (painter_test and device_looks_test own those), so every shape here
-- is pure reach-and-reach-back.
local function shape(x: number, y: number, channel: string): number?
    return t.network_joined(x, y, "pipe", channel)
end

local function said(p, want)
    for _, m in ipairs(t.messages(p)) do
        if m == want then
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------
-- ONE LENGTH, THEN A LINE, THEN A JUNCTION.
--
-- Bare plating, because pipe goes under the deck; every tile of it is
-- within one engineer's reach, so the run is laid without walking.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "a run being run",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#...#",
        "#####",
    ],
    structures: [(2, 2, "player_spawn")],
    items: [(2, 2, "pipe"), (1, 1, "wrench")],
)]==],
    7
)

local p = t.join()
t.tick()
t.click(p, 2, 2, t.target_at(p, 2, 2, "pipe"))
t.run_ticks(2)

-- ---- one length, alone ----
--
-- The first length of a run touches nothing, and tg draws that: shape 0
-- is a capped stub, not an absence. Note the two numbers disagreeing on
-- purpose -- the length REACHES every way (nobody has aimed it, which
-- is what `DIRS_ALL` means) and JOINS nothing at all. Reaching is not
-- joining; that gap is the whole of the rule.
t.click(p, 2, 2, nil, -14, 14)
t.run_seconds(1.5)
assert(network_channels.at(2, 2, "pipe") == "l3", "a length went down under the engineer")
assert(
    t.network_dirs(2, 2, "pipe", "l3") == N + S + E + W,
    "an unaimed length reaches every way: " .. tostring(t.network_dirs(2, 2, "pipe", "l3"))
)
assert(shape(2, 2, "l3") == 0, "and joins nothing: " .. tostring(shape(2, 2, "l3")))

-- Nothing on the tile is a THING: there is pipe under it and nothing a
-- click can name standing on it, because a length is not an entity and
-- has no layer stack for `t.layers` to read. (A MACHINE is the other
-- case, and the contrast is the point -- an in-line device is an atom,
-- and the stub it draws over its own mouth rides its entity layers,
-- since the sim is the only side that knows where a machine's mouths
-- are. device_looks_test.luau pins that one.)
assert(network_channels.at(2, 2, "pipe") ~= "", "there is pipe under the tile")
assert(t.target_at(p, 2, 2) == nil, "and nothing standing on it")
assert(t.target_at(p, 2, 2, "pipe") == nil, "the stack it came from is in a hand")

-- ---- extend it north: two stubs facing each other ----
t.click(p, 2, 1, nil, -14, 14)
t.run_seconds(1.5)
assert(shape(2, 2, "l3") == N, "the first length now reaches its neighbour")
assert(shape(2, 1, "l3") == S, "and the new one reaches back: a two-tile line")

-- ---- and south: a straight ----
t.click(p, 2, 3, nil, -14, 14)
t.run_seconds(1.5)
assert(
    shape(2, 2, "l3") == N + S,
    "three in a column draws the middle straight: " .. tostring(shape(2, 2, "l3"))
)
assert(shape(2, 3, "l3") == N, "with a cap at each end")

-- ---- branch east: a T ----
t.click(p, 3, 2, nil, -14, 14)
t.run_seconds(1.5)
assert(
    shape(2, 2, "l3") == N + S + E,
    "a branch makes the junction a T: " .. tostring(shape(2, 2, "l3"))
)
assert(shape(3, 2, "l3") == W, "and the branch is a stub off it")

-- ---- close the west arm: the cross ----
t.click(p, 1, 2, nil, -14, 14)
t.run_seconds(1.5)
assert(
    shape(2, 2, "l3") == N + S + E + W,
    "and the fourth arm closes the cross: " .. tostring(shape(2, 2, "l3"))
)
assert(t.ledger_has("NetworkPlaced"), "every length of it is on the record")

-- ---------------------------------------------------------------
-- PULL THE MIDDLE OUT AND FOUR ARMS BECOME FOUR STUBS.
--
-- The shape of a length is never stored, so nothing has to be told to
-- forget: the junction's tile stops carrying the layer and every
-- neighbour's picture falls out of the same derivation one length
-- later. This is why `PipeChanged` says the client must redraw the four
-- neighbours too.
-- ---------------------------------------------------------------
t.drop(p)
t.run_ticks(2)
t.click(p, 1, 1, t.target_at(p, 1, 1, "wrench"))
t.run_ticks(2)
t.click_network(p, 2, 2, assert(t.network_instance(2, 2, "pipe", "l3")))
t.run_seconds(1.5)

assert(network_channels.at(2, 2, "pipe") == "", "the junction came up")
for _, arm in ipairs({ { 2, 1 }, { 2, 3 }, { 3, 2 }, { 1, 2 } }) do
    local x, y = arm[1], arm[2]
    assert(network_channels.at(x, y, "pipe") == "l3", "the arm at " .. x .. "," .. y .. " is still there")
    assert(
        shape(x, y, "l3") == 0,
        "and is a capped stub again: " .. tostring(shape(x, y, "l3"))
    )
end
assert(t.ledger_has("NetworkRemoved"), "and pulling it is on the record")

-- ---------------------------------------------------------------
-- AN AIMED LENGTH DRAWS WHAT IT REACHES, NOT WHAT IT TOUCHES.
--
-- The same cross, mapped rather than built, with the centre length
-- aimed east-west and nothing else touched. Four lengths meet on that
-- tile and the picture is two lines passing -- Josh's ruling made
-- visible ("two pipes can carry poison and oxygen and run parallel;
-- they must NOT intersect"). An engineer reading this floor can see
-- that the north stub is not on the main.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "an aimed junction",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#...#",
        "#####",
    ],
    structures: [(1, 3, "player_spawn")],
    networks: [
        (x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 1, y: 2, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 2, y: 2, network: "pipe", channel: "l3", kind: "standard", facing: 12),
        (x: 3, y: 2, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 2, y: 3, network: "pipe", channel: "l3", kind: "standard", facing: 15),
    ],

)]==],
    7
)
t.join()
t.tick()

assert(t.network_dirs(2, 2, "pipe", "l3") == E + W, "the mapper aimed the centre across")
assert(
    shape(2, 2, "l3") == E + W,
    "so it draws as a straight line THROUGH the junction: " .. tostring(shape(2, 2, "l3"))
)
assert(shape(1, 2, "l3") == E, "the west length joins it")
assert(shape(3, 2, "l3") == W, "and so does the east one")
assert(
    shape(2, 1, "l3") == 0,
    "but the length lying against it from the north joins nothing at all,"
        .. " and is drawn as the stub it is: "
        .. tostring(shape(2, 1, "l3"))
)
assert(shape(2, 3, "l3") == 0, "and the same from the south")

-- ---------------------------------------------------------------
-- TWO LAYERS ON ONE TILE KEEP TWO PICTURES.
--
-- A distribution main runs east to west; an engineer walks the pipe
-- dial round to layer 1 and lays a line straight across it. The shape
-- is worked out one layer at a time, so the tile draws a horizontal
-- line and a vertical line crossing and never a four-way junction --
-- the reason a station runs a supply main and a waste line down one
-- corridor and stays readable.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "a crossing",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#...#",
        "#####",
    ],
    structures: [(2, 2, "player_spawn")],
    items: [(2, 2, "pipe")],
    networks: [
        (x: 1, y: 2, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 2, y: 2, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 3, y: 2, network: "pipe", channel: "l3", kind: "standard", facing: 15),
    ],
)]==],
    7
)

local e = t.join()
t.tick()
assert(shape(2, 2, "l3") == E + W, "the mapped main is a straight run")

t.click(e, 2, 2, t.target_at(e, 2, 2, "pipe"))
t.run_ticks(2)
local _ = t.messages(e)
for _ = 1, 3 do
    t.use_self(e) -- 3 -> 4 -> 5 -> 1, tg's wrapping cycle
    t.run_ticks(2)
end
assert(said(e, "Pipe layer set to 1."), "the dial wrapped round to the low layer")

for _, y in ipairs({ 1, 2, 3 }) do
    t.click(e, 2, y, nil, -14, 14)
    t.run_seconds(1.5)
end
assert(network_channels.at(2, 2, "pipe") == "l1,l3", "both layers are under the tile: " .. network_channels.at(2, 2, "pipe"))

assert(
    shape(2, 2, "l3") == E + W,
    "the main is drawn exactly as it was: " .. tostring(shape(2, 2, "l3"))
)
assert(
    shape(2, 2, "l1") == N + S,
    "the new line is drawn straight across it: " .. tostring(shape(2, 2, "l1"))
)
assert(shape(2, 1, "l1") == S, "with its own two ends reaching back at it")
assert(shape(2, 3, "l1") == N, "from north and south")
assert(t.network_dirs(2, 1, "pipe", "l3") == nil, "no distribution main runs up there")
assert(t.network_dirs(1, 2, "pipe", "l1") == nil, "and no low line runs out along the main")

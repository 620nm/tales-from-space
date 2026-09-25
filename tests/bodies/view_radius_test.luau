-- How far a crewman sees: `mod.toml [view] radius = 7`, tg's 15x15
-- world view (tgstation code/world.dm:15). The engine derives every
-- sight bound from the declared radius (the engine's
-- `docs/sim/view-radius.md`); this spec holds the pack to its number.
--
-- One corridor with nothing in the way and a locker at each end:
-- seven tiles is in sight, eight is not, and one step swaps them.

local CORRIDOR = [==[(
    name: "view corridor",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "##################",
        "#................#",
        "##################",
    ],
    structures: [
        (8, 1, "player_spawn"),
        (1, 1, "locker"),
        (16, 1, "locker"),
    ],
)]==]

t.world(CORRIDOR, 0)
local p = t.join()
t.run_ticks(2)

local x, y = t.pos(p)
assert(x == 8 and y == 1, ("the crewman stands at (8, 1), got (%d, %d)"):format(x, y))

local west = t.target_at(p, 1, 1, "locker")
assert(west ~= nil, "the locker seven tiles west is in sight")
assert(t.seen(p, west).kind ~= "unseen", "and streams to the one who sees it")
assert(t.target_at(p, 16, 1, "locker") == nil, "the locker eight tiles east is not")

-- One step east: the same two lockers, the answers swapped.
t.move(p, "east")
t.run_ticks(5) -- a step is rate-limited; give the cooldown room
x, y = t.pos(p)
assert(x == 9 and y == 1, ("one step east lands on (9, 1), got (%d, %d)"):format(x, y))

assert(t.target_at(p, 16, 1, "locker") ~= nil, "now the east locker is seven tiles off and seen")
assert(t.target_at(p, 1, 1, "locker") == nil, "and the west one, eight tiles off, has left view")

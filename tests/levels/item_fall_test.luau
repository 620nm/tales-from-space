-- Every item falls, as in tg (`/turf/proc/zFall` lets any object drop,
-- tgstation/code/game/turfs/turf.dm:335-361; content/lib/item_fall.luau). The
-- engine asks `item.fall` for a thing resting over an Open tile and this
-- pack's one unscoped answer says yes: a crowbar thrown onto a hole, and a
-- crowbar whose floor is dug out from under it, both end on the level below
-- with a `level_changed` row via "fall".
--
-- Not covered: an item DROPPED onto a hole (cause `drop`). A hand drop lands
-- on the player's own tile and a body cannot stand, or join, on an Open tile,
-- so no player action reaches it; the engine's fixture tests own that path.
local UPPER = 1
local LOWER = 0

t.world(
    [==[(
    name: "item fall",
    tags: ["terrestrial"],
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '_': (composition: (components: [(component: "station_base")])),
        'o': (composition: (substrate: Open)),
    },
    levels: [
        (
            rows: [
                "#######",
                "#.....#",
                "#######",
            ],
            structures: [],
        ),
        (
            rows: [
                "#######",
                "#..o._#",
                "#######",
            ],
            structures: [(1, 1, "player_spawn")],
            items: [(1, 1, "crowbar"), (5, 1, "crowbar")],
        ),
    ],
)]==],
    0,
    "free_build"
)

local p = t.join()
t.run_ticks(4)
assert(#t.ledger_rows("level_changed") == 0, "nothing has fallen yet")
assert(#t.items_at(5, 1, UPPER) == 1, "the second crowbar lies on the upper deck")

-- 1. Thrown: a crowbar flung onto the hole at (3, 1) comes to rest over it
-- and drops to the lower level under it.
t.click(p, 1, 1, t.target_at(p, 1, 1, "crowbar"))
t.run_ticks(2)
assert(t.hands(p).held == "crowbar", "the crowbar is in hand")
t.throw(p, 3, 1)
t.run_seconds(3)

local falls = t.ledger_rows("level_changed")
assert(#falls == 1, "one level_changed row for the thrown crowbar, got " .. #falls)
assert(falls[1].via == "fall" and falls[1].levels == 1, "it fell one level, via " .. tostring(falls[1].via))
assert(#t.items_at(3, 1, UPPER) == 0, "nothing is left over the hole")
local below = t.items_at(3, 1, LOWER)
assert(#below == 1 and below[1] == "crowbar", "the crowbar lies on the lower level under the hole")

-- 2. Dug out from under: the crowbar at (5, 1) rests on plating; baring the
-- tile leaves it over open air.
assert(t.set_composition(5, 1, "bare", UPPER), "the bare preset digs the plating out")
t.run_seconds(3)

falls = t.ledger_rows("level_changed")
assert(#falls == 2 and falls[2].via == "fall", "the dug tile drops the second crowbar, got " .. #falls .. " rows")
assert(#t.items_at(5, 1, UPPER) == 0, "the crowbar has left the dug tile")
below = t.items_at(5, 1, LOWER)
assert(#below == 1 and below[1] == "crowbar", "the second crowbar lies on the lower level too")

assert(#t.ledger_rows("item_fall_stayed") == 0, "this pack never answers stay")
local x, y = t.pos(p)
assert(x == 1 and y == 1, "the thrower never moved, got (" .. x .. ", " .. y .. ")")

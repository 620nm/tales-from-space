local matter_look = require("@helpers/matter_look")

-- Gas and liquid sit flush against anything that seals; solids stay soft.
--
-- One tile holds all three at once: a litre of water, thirty moles of
-- chlorine and sixty millilitres of ash. A litre is a millimetre over a
-- tile and under the water's 3.3 mm film, so it stays where it fell and
-- the picture is the only thing that moves. Its north is a glazed
-- window, its south a wall, its east a shut airlock leaf and its west
-- open deck. The client joins a shell across a side that seals, so the
-- first three sides read as joined and the open one as a rounded edge
-- (the engine's docs/looks/matter.md section 5). The ash is a pile: it
-- ignores the seals and rounds off on all four.
--
-- Then the leaf is pried open. The east side stops sealing and the
-- puddle's quadrants on that side fall back to the soft edge.

t.set_breathing(false)

t.world(
    [==[(
    name: "seal edges",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '+': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Door)),
    },
    levels: [
        (
            rows: [
                "#######",
                "###.###",
                "#...+.#",
                "#######",
            ],
            structures: [(1, 2, "player_spawn"), (3, 1, "grille", "glazed")],
            items: [(2, 2, "crowbar")],
            painted: [(3, 2, "spill")],
        ),
    ],
    blends: {
        "spill": (rows: [("water", 55.51), ("chlorine", 30.0), ("ash", 1.32), ("o2", 26.19), ("n2", 98.53)], temperature_k: 293.15, amount: total),
    },
)]==],
    0
)

local p = t.join()
t.tick()
local X, Y = 3, 2

-- Shut: the puddle fills against the window, the wall and the leaf.
local puddle = assert(matter_look.find(p, X, Y, "puddle", 4), "a litre draws the puddle shell")
local joins, quadrants = matter_look.edges(puddle)
assert(joins.n and joins.s and joins.e, "the window, the wall and the shut leaf all read as joined")
assert(not joins.w, "the open deck to the west is a dry tile, so it is an edge")
assert(not puddle.whole, "an edge on one side is not a whole tile")
assert(quadrants.ne == "flat" and quadrants.se == "flat", "both eastern quarters sit flush")
assert(quadrants.nw == "vertical" and quadrants.sw == "vertical", "the western quarters run along the seals and round off open")

-- The same flush rule, on the gas the tile holds.
for _, rung in ipairs({ 1, 2, 3 }) do
    local cloud = assert(matter_look.find(p, X, Y, "cloud", rung), "chlorine at thirty moles draws every cloud rung")
    local cloud_joins = matter_look.edges(cloud)
    assert(cloud_joins.n and cloud_joins.s and cloud_joins.e and not cloud_joins.w, "the cloud is flush on the seals, rounded to the open side")
end

-- A pile of ash ignores the seals: a soft look is not a container.
local ash = assert(matter_look.find(p, X, Y, "powder", 2), "sixty millilitres of ash draw the sheet")
local ash_joins, ash_quadrants = matter_look.edges(ash)
assert(
    not (ash_joins.n or ash_joins.s or ash_joins.e or ash_joins.w),
    "ash does not fill against the window, the wall or the leaf"
)
assert(
    ash_quadrants.nw == "convex" and ash_quadrants.ne == "convex" and ash_quadrants.sw == "convex" and ash_quadrants.se == "convex",
    "and rounds off on every side"
)

-- Pry the leaf open.
t.click(p, 2, 2, t.target_at(p, 2, 2, "crowbar"))
t.tick()
assert(t.hands(p).held == "crowbar", "the crowbar is in hand")
t.move(p, "east")
t.run_ticks(4)
t.move(p, "east")
t.run_ticks(4)
assert(not assert(t.door_at(4, 2)).powered, "the leaf is dark, so nothing shuts it again")
t.click(p, 4, 2, t.target_at(p, 4, 2))
t.run_seconds(4)
assert(assert(t.door_at(4, 2)).open, "pried open")

local open_puddle = assert(matter_look.find(p, X, Y, "puddle", 4), "the puddle is still a puddle")
local open_joins, open_quadrants = matter_look.edges(open_puddle)
assert(not open_joins.e, "an open doorway seals nothing, and the tile beyond it is dry")
assert(open_joins.n and open_joins.s, "the window and the wall still do")
assert(
    open_quadrants.ne == "vertical" and open_quadrants.se == "vertical",
    "so the eastern quarters fall back to the soft edge"
)

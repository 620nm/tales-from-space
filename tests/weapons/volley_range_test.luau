local ui_controls = require("@helpers/ui_controls")

-- How far a grenade's pellets fly: four witnesses stand past the direct
-- blast on the first volley's own rays, and the volley is the only thing
-- that can reach them. The direct blast ends at a tile and a half; burn
-- anywhere past it would name a leak, while brute past it names a pellet.
--
-- The watched rays leave the blast tile (7, 7) on volley id 0's spread
-- (24 degrees apart, no golden-angle turn yet): due east down row 7 to
-- the east witness at (12, 7), the two pure diagonals to (11, 11) and
-- (11, 3), and the west pair through (5, 7), which both strike before
-- they fork past (4, 7). Nobody stands ahead of anyone on a ray, and
-- the armer retreats west off every one, so each witness reads its own
-- ray's reach.
t.world(
    [==[(
    name: "volley range",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "###############",
        "#.............#",
        "#.............#",
        "#.............#",
        "#.............#",
        "#.............#",
        "#.............#",
        "#.............#",
        "#.............#",
        "#.............#",
        "#.............#",
        "#.............#",
        "#.............#",
        "#.............#",
        "###############",
    ],
    structures: [(1, 1, "player_spawn")],
    items: [(7, 7, "frag_grenade")],
)]==],
    0
)

local arm = t.join()
local e = t.join()
local se = t.join()
local ne = t.join()
local w = t.join()
t.tick()

local function walk(p: number, moves: { "east" | "north" | "south" | "west" }): ()
    for _, dir in ipairs(moves) do
        t.move(p, dir)
        t.run_ticks(6)
    end
end

local function burn(p: number): number
    return ui_controls.number(t.health(p).burn)
end

local function brute(p: number): number
    return ui_controls.number(t.health(p).brute)
end

local function placed(p: number, x: number, y: number, who: string): ()
    local px, py = t.pos(p)
    assert(px == x and py == y, ("%s stands at (%d, %d), got (%d, %d)"):format(who, x, y, px, py))
end

-- The witnesses post first, each on its own ray and none ahead of
-- another; the armer's own walks stay on row 1, column 7 and row 7 west
-- of the blast, off every watched ray.
walk(e, { "east", "east", "east", "east", "east", "east", "east", "east", "east", "east", "east", "south", "south", "south", "south", "south", "south" })
walk(se, { "east", "east", "east", "east", "east", "east", "east", "east", "east", "east", "south", "south", "south", "south", "south", "south", "south", "south", "south", "south" })
walk(ne, { "east", "east", "east", "east", "east", "east", "east", "east", "east", "east", "south", "south" })
walk(w, { "east", "east", "east", "east", "south", "south", "south", "south", "south", "south" })
placed(e, 12, 7, "the east witness")
placed(se, 11, 11, "the southeast witness")
placed(ne, 11, 3, "the northeast witness")
placed(w, 5, 7, "the west witness")

walk(arm, { "east", "east", "east", "east", "east", "east", "south", "south", "south", "south", "south", "south" })
placed(arm, 7, 7, "the armer")
t.click(arm, 7, 7, t.target_at(arm, 7, 7, "frag_grenade"))
t.tick()
assert(t.hands(arm).held == "frag_grenade", "the grenade is in hand")
t.use_self(arm)
t.tick()
t.drop(arm)
t.tick()
walk(arm, { "west", "west", "west", "west", "west", "west" })
placed(arm, 1, 7, "the retreated armer")

t.run_seconds(6)
assert(#t.ledger_rows("item_destroyed") == 1, "one fuse, one detonation")

local discharged = t.ledger_rows("volley_discharged")
local settled = t.ledger_rows("volley_settled")
assert(#discharged == 1, "one blast, one volley")
assert(#settled == 1, "settled by the tick")
assert(discharged[1].radius == 10, "thrown to ten tiles")
assert(discharged[1].fragments == 15, "fifteen pellets in the air")
assert(discharged[1].damage == 14, "at tg's shrapnel force")
assert(settled[1].fragments == 15, "fifteen pellets home")
assert(discharged[1].seq < settled[1].seq, "the pair brackets the flight")

-- Past the blast, no burn: the direct blow ends at a tile and a half,
-- and every witness stands four or five out.
assert(burn(e) == 0, "five east, no burn")
assert(burn(se) == 0, "four southeast, no burn")
assert(burn(ne) == 0, "four northeast, no burn")
assert(burn(w) == 0, "two west, no burn")
assert(burn(arm) == 0, "six west, the armer feels no blast either")

-- But the pellets reach: one strike each down the east ray and the two
-- diagonals, two where the west pair crosses, every one of them brute
-- the blast could never have dealt. Floors, not exact: a ricochet off a
-- far wall can only add strikes, never take them away.
assert(brute(e) >= 10, ("the east ray lands: %g brute"):format(brute(e)))
assert(brute(se) >= 10, ("the southeast ray lands: %g brute"):format(brute(se)))
assert(brute(ne) >= 10, ("the northeast ray lands: %g brute"):format(brute(ne)))
assert(brute(w) >= 20, ("the west pair lands: %g brute"):format(brute(w)))

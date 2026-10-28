local composition = require("@helpers/composition")

-- A crowbar pries up each of the four glass floors for its tile, instantly,
-- and leaves plating, not a hole: tg glass floors are ordinary floors with
-- a `floor_tile` (glass.dm:16,74,92,108), so `crowbar_act` -> `pry_tile` ->
-- `remove_tile` -> `make_plating` applies (floor.dm:144-174, :110-111).
-- Without a crowbar nothing happens. Laying a glass tile back is not ported.

local BASEMENT = -1
local GROUND = 0
local PRY_SAY = "You pry up the glass floor tile."

local function has(list: { string }, want: string): boolean
    for _, v in ipairs(list) do
        if v == want then
            return true
        end
    end
    return false
end

type GlassFloor = { x: number, component: string, tile: string }
local floors: { GlassFloor } = {
    { x = 2, component = "glass_floor", tile = "glass_tile" },
    { x = 3, component = "reinforced_glass_floor", tile = "reinforced_glass_tile" },
    { x = 4, component = "plasma_glass_floor", tile = "plasma_glass_tile" },
    { x = 5, component = "reinforced_plasma_glass_floor", tile = "reinforced_plasma_glass_tile" },
}

t.world(
    [==[(
    name: "glass floors",
    tags: ["terrestrial"],
    levels_below_ground: 1,
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'g': (composition: (substrate: Open, components: [(component: "glass_floor")])),
        'r': (composition: (substrate: Open, components: [(component: "reinforced_glass_floor")])),
        'p': (composition: (substrate: Open, components: [(component: "plasma_glass_floor")])),
        'q': (composition: (substrate: Open, components: [(component: "reinforced_plasma_glass_floor")])),
        'R': (composition: (components: [(component: "rock")])),
        'c': (composition: ()),
    },
    levels: [
        (
            rows: [
                "RRRRRRRR",
                "RccccccR",
                "RRRRRRRR",
            ],
            structures: [],
        ),
        (
            rows: [
                "########",
                "#.grpq.#",
                "########",
            ],
            items: [(1, 1, "crowbar")],
            structures: [(1, 1, "player_spawn")],
        ),
    ],
)]==],
    0,
    "free_build"
)

local p = t.join()
t.run_ticks(4)

-- A bare hand beside the nearest floor does nothing to it.
t.click_component(p, 2, 1, assert(t.component_instance(2, 1, "glass_floor")))
t.tick()
assert(composition.matches(2, 1, { "glass_floor" }), "a bare hand leaves the glass floor alone")
assert(not has(t.items_at(2, 1, GROUND), "glass_tile"), "and no tile comes of it")

t.click(p, 1, 1, t.target_at(p, 1, 1, "crowbar")) -- the crowbar is underfoot
t.tick()
assert(t.hands(p).held == "crowbar", "the crowbar is in hand")

local function walk_east()
    t.move(p, "east")
    t.run_ticks(5) -- MOVE_COOLDOWN_TICKS, one step per press
end

for index, floor in ipairs(floors) do
    assert(#t.seen_composition(p, floor.x, 1, BASEMENT) > 0, floor.component .. " shows the basement")
    t.sounds(p) -- clear earlier traffic
    t.messages(p)
    t.click_component(p, floor.x, 1, assert(t.component_instance(floor.x, 1, floor.component)))
    t.tick()
    assert(
        composition.matches(floor.x, 1, { "station_base" }),
        floor.component .. " pries up to plating: " .. composition.describe(floor.x, 1)
    )
    assert(has(t.items_at(floor.x, 1, GROUND), floor.tile), floor.tile .. " is refunded where the floor lay")
    assert(
        t.stack_count(assert(t.target_at(p, floor.x, 1, floor.tile))) == 1,
        "exactly one tile comes up (floor.dm:179-182)"
    )
    assert(has(t.messages(p), PRY_SAY), "and the narration says so")
    assert(has(t.sounds(p), "crowbar"), "with the crowbar's quick pop")
    assert(#t.seen_composition(p, floor.x, 1, BASEMENT) == 0, "the plating hides the basement")
    if index < #floors then
        walk_east() -- onto the plating just laid bare, in reach of the next floor
    end
end

assert(#t.ledger_rows("level_changed") == 0, "nobody fell: plating holds, a hole would not")

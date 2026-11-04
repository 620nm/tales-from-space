local composition = require("@helpers/composition")

-- A vessel on open ground: a bottle tips out onto sand as it would onto a
-- deck, and a mop takes the puddle back up. No sea here: a spill on a
-- shore runs into it (sea_shore_test).
--
-- Sand, with one column of ground raised a level at (2, 0), a full block of
-- basalt that no spill can lie on. The
-- player stands at (2, 1) with a bottle of water and a mop, and a litre
-- stands at (3, 1). The bottle's 22 mL is under what the air
-- over a tile takes up as vapour, so it is gone in a second or two: the
-- mop gets the litre.
t.world(
    [==[(
    name: "ground vessels",
    needs: ["gravity"],
    environment: (kind: Exact(terrestrial), surface_temperature_k: Exact(293.15)),
    legend: {
        'a': (outdoors: true, composition: (substrate: Named("ground"), material: Named("sand_ground"), components: [])),
        'c': (composition: ()),
    },
    ground: (legend: { '^': (height: 1, material: Some(Blend("basalt_ground"))) }, rows: ["..^..", ".....", "....."]),
    levels: [
        (
            rows: [
                "aacaa",
                "aaaaa",
                "aaaaa",
            ],
            structures: [(2, 1, "player_spawn")],
            painted: [(3, 1, "puddle")],
            items: [
                (2, 1, "water_bottle"),
                (2, 1, "mop"),
            ],
        ),
    ],
    blends: {
        "puddle": (rows: [("water", 55.51)], temperature_k: 293.15, amount: total),
    },
)]==],
    0,
    "free_build"
)
t.set_breathing(false)

local WATER_ML_PER_MOL = 18.015 -- substances/water.luau, 1 g/mL

-- The painted litre carries no air: let the sky fill it before anyone
-- stands beside it.
t.run_seconds(20)
local p = t.join()
t.tick()

local bottle = assert(t.target_at(p, 2, 1, "water_bottle"))
local mop = assert(t.target_at(p, 2, 1, "mop"))

local function held(handle): number
    local contents = assert(t.contents(handle), "that is a vessel")
    return contents.water or 0
end

local function sand_litres(): number
    local total = 0
    for x = 0, 2 do
        for y = 0, 2 do
            local liquid = t.room_liquid(x, y)
            total += if liquid then liquid.water or 0 else 0
        end
    end
    return total
end

local function said(): string
    local lines = t.messages(p)
    return lines[#lines] or ""
end

t.click(p, 2, 1, bottle)
t.tick()
assert(t.hands(p).held == "water_bottle", "the bottle is in hand")
t.use_self(p)
t.tick()
t.messages(p)

local full = held(bottle)
assert(full > 1, "a full bottle, got " .. full .. " mol")

-- RAISED GROUND holds no spill: refused out loud, and the bottle keeps its water.
composition.click_deck(p, 2, 0)
t.tick()
local refused = said()
assert(refused == "There is no footing there to tip the bottle out onto.", "the raised ground refuses: " .. refused)
assert(math.abs(held(bottle) - full) < 1e-6, "the bottle is still full")

-- POURING onto sand: the click reaches the handler on open ground, not
-- only on plating.
composition.click_deck(p, 1, 1)
t.tick()
local tipped = said()
assert(tipped == "You tip the bottle out onto the ground.", "the spill is reported: " .. tipped)
assert(held(bottle) < 1e-4, "the bottle is empty, got " .. held(bottle))
local want = full * WATER_ML_PER_MOL / 1000
local puddle = sand_litres()
assert(math.abs(puddle - want) < 0.1 * want, ("the sand holds the spill: %g L of %g"):format(puddle, want))

-- MOPPING the sand: the stroke takes the puddle back up.
t.drop(p)
t.tick()
t.click(p, 2, 1, mop)
t.tick()
assert(t.hands(p).held == "mop", "the mop is in hand")
t.messages(p)
local HEAD_L = 0.25 -- the mop's head (mop_test)
local standing = assert(t.room_liquid(3, 1)).water or 0
assert(standing > 2 * HEAD_L, ("the litre is standing, %g L"):format(standing))
composition.click_deck(p, 3, 1)
t.tick()
t.run_seconds(1.6)
local stroke = said()
assert(stroke == "You run the mop over the ground.", "the stroke is reported: " .. stroke)
local lifted = held(mop) * WATER_ML_PER_MOL / 1000
assert(lifted > 0.9 * HEAD_L, ("the mop takes a head off the ground: %g L"):format(lifted))

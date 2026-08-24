-- What a bottle of gas does when you open it, and the two ways a
-- station operator can watch nothing happen instead.
--
-- The cloud is a DERIVED thing. A room cell is drawn tinted when it
-- holds enough of a substance whose file declared a `visible` block,
-- so what makes a chlorine cloud is chlorine gas being in the room --
-- and every way of getting it there ends at the same moles. This spec
-- asserts the moles, because the moles are the mechanism and the
-- overlay is arithmetic over them.
--
-- The two ways to watch nothing happen are both real reports:
--
--   1. **The wrong half of a pair.** This pack models `chlorine` (the
--      reagent -- tg's single atom, whose salt recipe is 1:1 with
--      sodium) and `cl2` (the diatomic molecule with a real phase
--      curve and the yellow-green everybody recognises). They are two
--      substances a word apart, and only one of them is a gas. A
--      canister commissioned full of the reagent used to hold
--      gas-phase matter that could not boil, could not condense, took
--      part in no reaction and had no colour: every symptom of an
--      empty bottle, and no complaint anywhere. It is now a refusal at
--      the fill.
--   2. **A bottle wrenched onto a port.** That is not a leak and not a
--      failure -- a canister on a connector port releases into the
--      RUN, which is the entire point of a distribution main. Nothing
--      appears on the deck because nothing was released onto it.
--
-- No player: every assertion here is about what a room holds, and a
-- crewman standing in a vacuum full of chlorine would be a distraction
-- with a very short future.

-- cl2's own visibility threshold, out of its file: a quarter of it is
-- where tg starts drawing a gas at all, and this pack draws chlorine
-- from 0.15 mol. Spelled here because a SPEC is allowed to know the
-- pack's numbers -- that is what makes it a spec.
local VISIBLE_MOL = 0.15

local function held(x, y, key)
    return (t.room_gas(x, y) or {})[key] or 0.0
end

local function in_pipe(x, y, key)
    return (t.pipe_gas(x, y) or {})[key] or 0.0
end

-- Three bays behind three walls, each pumped down to nothing so a
-- bottle has somewhere to release INTO, and each with one bottle in it.
--
--   A (1..2, 1) -- a hundred moles of chlorine gas, hot.
--   B (4..5, 1) -- the same recipe naming the REAGENT instead.
--   C (7..8, 1) -- the same gas again, on a connector port.
--
-- The canister shell is 2 m3 and a recipe is moles PER TILE, so 50 in
-- the file is 100 in the bottle.
t.world([==[(
    name: "three bays",
    legend: {
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "##########",
        "#..#..#..#",
        "##########",
    ],
    spawns: [(1, 1)],
    pipes: [(8, 1, 4)],
    air_presets: {
        "pumped_down": (temperature_k: 293.15),
        "hot_cl2": (gases: [("cl2", 50.0)], temperature_k: 1000.0),
        "by_the_wrong_name": (gases: [("chlorine", 50.0)], temperature_k: 1000.0),
    },
    air: [
        (1, 1, "pumped_down"), (2, 1, "pumped_down"),
        (4, 1, "pumped_down"), (5, 1, "pumped_down"),
        (7, 1, "pumped_down"), (8, 1, "pumped_down"),
    ],
    structures: [
        (1, 1, "canister", { "air": "hot_cl2", "open": true }),
        (4, 1, "canister", { "air": "by_the_wrong_name", "open": true }),
        (7, 1, "connector_port"),
        // Wound up past the main's commissioned atmosphere, because a
        // canister only pushes UP TO its setpoint: a bottle set to one
        // atmosphere on a main already at one has nothing to do, which
        // is the machine working and not what this bay is about.
        (7, 1, "canister", { "air": "hot_cl2", "open": true, "release_kpa": 400.0 }),
    ],
)]==], 7)

t.tick()

-- ---- the bottle that was filled with a gas ----
assert(t.canister_pressure(1, 1) > 0.0, "bay A's bottle is charged")

t.run_seconds(20)

local cloud = held(1, 1, "cl2")
assert(cloud > 0.0, "the bottle released into the room it stands in")
assert(
    cloud > VISIBLE_MOL,
    "and there is enough of it in the cell to draw: " .. cloud .. " mol"
)
assert(held(2, 1, "cl2") > VISIBLE_MOL, "the bay filled, not just the tile under it")
assert(t.room_pressure(1, 1) > 1.0, "which reads on a gauge too")

-- ---- the bottle that was filled with the wrong half of a pair ----
--
-- Refused at the fill, so the bottle is empty and stays empty. That is
-- the whole fix: an empty bottle is a thing an operator can see, and
-- gas-phase matter that can never do anything is not.
assert(
    t.canister_pressure(4, 1) < 0.001,
    "the reagent was refused rather than deposited: " .. t.canister_pressure(4, 1) .. " kPa"
)
assert(held(4, 1, "chlorine") == 0.0, "so nothing of it reached the deck")
assert(held(4, 1, "cl2") == 0.0, "and it certainly did not become the gas")
assert(
    t.room_pressure(4, 1) < 0.001,
    "the bay is the vacuum it was painted: " .. t.room_pressure(4, 1) .. " kPa"
)

-- ---- the bottle on a port ----
--
-- Correct plumbing, and the confounder worth pinning: what comes out
-- of this one goes into the RUN. A deck that stays clean here is the
-- machine working.
assert(in_pipe(8, 1, "cl2") > 0.0, "the port carried it into the main")
assert(
    held(7, 1, "cl2") < VISIBLE_MOL and held(8, 1, "cl2") < VISIBLE_MOL,
    "and none of it was released onto the deck: "
        .. held(7, 1, "cl2") .. " / " .. held(8, 1, "cl2")
)
assert(
    t.room_pressure(7, 1) < 1.0,
    "the bay stayed pumped down: " .. t.room_pressure(7, 1) .. " kPa"
)

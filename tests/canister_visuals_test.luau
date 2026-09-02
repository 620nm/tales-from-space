-- What a bottle of gas does when you open it, and the way a station
-- operator can watch nothing happen instead.
--
-- The cloud is a DERIVED thing. A room cell is drawn tinted when it
-- holds enough of a substance whose file declared a `visible` block,
-- so what makes a chlorine cloud is chlorine gas being in the room --
-- and every way of getting it there ends at the same moles. This spec
-- asserts the moles, because the moles are the mechanism and the
-- overlay is arithmetic over them.
--
-- THE WAY TO WATCH NOTHING HAPPEN is a real report: a bottle wrenched
-- onto a port. That is not a leak and not a failure -- a canister on a
-- connector port releases into the RUN, which is the entire point of a
-- distribution main. Nothing appears on the deck because nothing was
-- released onto it.
--
-- There used to be a second one, and it is worth saying why it is
-- gone. This pack carried the chlorine ATOM (so tg's 1:1 salt recipe
-- kept its arithmetic) and the chlorine MOLECULE beside it, under two
-- ids a word apart, only one of which was a gas,
-- and a canister commissioned full of the wrong one held matter that
-- could not boil, could not condense and had no colour. There is one
-- id per molecule now: the pair does not exist, so neither does the
-- bay that caught it.
--
-- No player: every assertion here is about what a room holds, and a
-- crewman standing in a vacuum full of chlorine would be a distraction
-- with a very short future.

-- Chlorine's own visibility threshold, out of its file: a quarter of a
-- mole is where tg starts drawing a gas at all, and this pack draws
-- chlorine from 0.15. Spelled here because a SPEC is allowed to know
-- the pack's numbers -- that is what makes it a spec.
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
--   A (1..2, 1) -- a hundred moles of chlorine, hot, valve open.
--   B (4..5, 1) -- the same bottle on a connector port, valve shut.
--   C (7..8, 1) -- the same again with the valve open too: the trap.
--
-- The canister shell is 2 m3 and a recipe is moles PER TILE, so 50 in
-- the file is 100 in the bottle. HOT, because chlorine has a real
-- phase curve: at 1000 K there is nothing to condense and the bottle
-- holds gas, which is what this file is about.
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
    pipes: [(5, 1, 4), (8, 1, 4)],
    blends: {
        "pumped_down": (temperature_k: 293.15, amount: per_tile),
        "hot_chlorine": (rows: [("chlorine", 50.0)], temperature_k: 1000.0, amount: per_tile),
    },
    painted: [
        (1, 1, "pumped_down"), (2, 1, "pumped_down"),
        (4, 1, "pumped_down"), (5, 1, "pumped_down"),
        (7, 1, "pumped_down"), (8, 1, "pumped_down"),
    ],
    structures: [
        (1, 1, "canister", { "blend": "hot_chlorine", "open": true }),
        (4, 1, "connector_port"),
        // Valve SHUT, because the wrench is the coupling: a fastened
        // bottle equalises with its run with no valve in the story
        // (tg's connector reconciliation), and OPENING the valve on a
        // ported bottle vents the DECK -- tg's own trap, pinned below.
        (4, 1, "canister", { "blend": "hot_chlorine" }),
        (7, 1, "connector_port"),
        // The TRAP, as mapped: fastened AND open. The wrench couples it
        // to the run; the valve gasses the deck. Both at once, which is
        // exactly what tg's two independent couplings mean.
        (7, 1, "canister", { "blend": "hot_chlorine", "open": true }),
    ],
)]==], 7)

t.tick()

-- ---- the bottle that was filled with a gas ----
assert(t.canister_pressure(1, 1) > 0.0, "bay A's bottle is charged")

t.run_seconds(20)

local cloud = held(1, 1, "chlorine")
assert(cloud > 0.0, "the bottle released into the room it stands in")
assert(
    cloud > VISIBLE_MOL,
    "and there is enough of it in the cell to draw: " .. cloud .. " mol"
)
assert(held(2, 1, "chlorine") > VISIBLE_MOL, "the bay filled, not just the tile under it")
assert(t.room_pressure(1, 1) > 1.0, "which reads on a gauge too")

-- ---- the bottle on a port ----
--
-- Correct plumbing, and the confounder worth pinning: a fastened
-- bottle is part of the RUN -- its charge equalises into the main with
-- the valve never touched. A deck that stays clean here is the machine
-- working; the valve's own trap gets its pin at the end of the file.
assert(in_pipe(5, 1, "chlorine") > 0.0, "the port carried it into the main")
assert(
    held(4, 1, "chlorine") < VISIBLE_MOL and held(5, 1, "chlorine") < VISIBLE_MOL,
    "and none of it was released onto the deck: "
        .. held(4, 1, "chlorine") .. " / " .. held(5, 1, "chlorine")
)
assert(
    t.room_pressure(4, 1) < 1.0,
    "the bay stayed pumped down: " .. t.room_pressure(4, 1) .. " kPa"
)

-- ---- the trap ----
--
-- Opening the valve on a PORTED bottle vents the deck: the valve
-- reaches the room whether or not the wrench has coupled the bottle to
-- a run (tg canister.dm:549, `holding?.return_air() ||
-- location.return_air()` -- a connected port never appears there).
-- tg's engineers leave a ported valve shut, and now ours have the same
-- reason to.
assert(in_pipe(8, 1, "chlorine") > 0.0, "the wrench coupled it to the run")
assert(
    held(7, 1, "chlorine") > 0.0,
    "and the open valve gassed the deck it stands on"
)

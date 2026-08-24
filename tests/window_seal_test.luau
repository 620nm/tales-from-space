-- "The chlorine seems to immediately bleed through the reinforced
-- glass."
--
-- It did, and the pane was never the problem: the seal on a shared
-- edge belonged to whichever tile resealed LAST. A window sealed its
-- links when it spawned; any ordinary structure spawning on the tile
-- beside it afterwards said "nothing on me holds air back" as a
-- broadcast over ALL its links -- the shared one included -- and the
-- pane stood there looking airtight over an open edge. Spawn-order
-- dependent, so a mapper met it or did not by luck of the structures
-- list.
--
-- The contract now: an edge is sealed while EITHER of its tiles holds
-- air back (sim/geometry.rs reseal_tile), so no neighbour can open a
-- window from the outside. Both spawn orders are built below, because
-- the order was the whole bug.
--
-- What still crosses is HEAT, on purpose: superconduction through a
-- pane is tg's own physics (WINDOW_HEAT_TRANSFER), and it is what a
-- hot chamber does to the corridor outside -- pressure and warmth,
-- never matter. The spec pins that too, so the fix for the leak can
-- never quietly become "windows are adiabatic".

local CHAMBER = { { 1, 1 }, { 2, 1 }, { 3, 1 }, { 1, 2 }, { 2, 2 }, { 3, 2 }, { 1, 3 }, { 2, 3 }, { 3, 3 } }
local OUTSIDE = { { 4, 1 }, { 4, 2 }, { 4, 3 }, { 5, 2 }, { 6, 2 } }
local SEEDED = 9 * 250.0

local function cl2_at(x, y)
    local g = t.room_gas(x, y) or {}
    return g.cl2 or 0.0
end

local function pipe_cl2(x, y)
    local g = t.pipe_gas(x, y) or {}
    return g.cl2 or 0.0
end

local function check(order)
    t.run_ticks(200)
    -- Not one molecule outside: the pane holds, the pane's own tile
    -- holds, and the corridor past it holds.
    for _, at in ipairs(OUTSIDE) do
        assert(cl2_at(at[1], at[2]) == 0.0, string.format(
            "%s: cl2 escaped to (%d,%d)", order, at[1], at[2]))
    end
    -- Every mole accounted for: what the chamber kept plus what the
    -- room traded into the run under it (the meter's stub holds the
    -- chamber's own air; that is plumbing, not a leak).
    local held = 0.0
    for _, at in ipairs(CHAMBER) do
        held += cl2_at(at[1], at[2])
    end
    held += pipe_cl2(3, 2)
    assert(math.abs(held - SEEDED) < 1e-6, string.format(
        "%s: %.6f of %.1f mol accounted for", order, held, SEEDED))
    -- The window is a window, not a vacuum flask: the far side warms.
    assert((t.room_temperature(4, 2) or 0) > 350.0,
        order .. ": heat still conducts through the pane")
    assert((t.room_temperature(5, 2) or 0) > 300.0,
        order .. ": and past it")
end

-- ---------------------------------------------------------------
-- Windows first, neighbour after: the order that leaked.
-- ---------------------------------------------------------------
t.world([==[(
    name: "windows first",
    legend: { '.': (turf: Plating), '#': (turf: Wall) },
    rows: [
        "#########",
        "#.......#",
        "#.......#",
        "#.......#",
        "#########",
    ],
    spawns: [ (6, 3) ],
    structures: [
        (4, 1, "grille", "reinforced"),
        (4, 2, "grille", "reinforced"),
        (4, 3, "grille", "reinforced"),
        (3, 2, "meter"),
    ],
    pipes: [ (3, 1, 4), (3, 2, 4), (3, 3, 4) ],
    air_presets: {
        "hot_chlorine": (gases: [("cl2", 250.0)], temperature_k: 1000.0),
        "standard_air": (gases: [("o2", 8.73), ("n2", 32.84)], temperature_k: 293.15),
    },
    air: [
        (1, 1, "hot_chlorine"), (2, 1, "hot_chlorine"), (3, 1, "hot_chlorine"),
        (1, 2, "hot_chlorine"), (2, 2, "hot_chlorine"), (3, 2, "hot_chlorine"),
        (1, 3, "hot_chlorine"), (2, 3, "hot_chlorine"), (3, 3, "hot_chlorine"),
    ],
)]==])
check("windows-first")

-- ---------------------------------------------------------------
-- Neighbour first, windows after: the order that happened to work,
-- kept so the contract is the pair and not one lucky listing.
-- ---------------------------------------------------------------
t.world([==[(
    name: "neighbour first",
    legend: { '.': (turf: Plating), '#': (turf: Wall) },
    rows: [
        "#########",
        "#.......#",
        "#.......#",
        "#.......#",
        "#########",
    ],
    spawns: [ (6, 3) ],
    structures: [
        (3, 2, "meter"),
        (4, 1, "grille", "reinforced"),
        (4, 2, "grille", "reinforced"),
        (4, 3, "grille", "reinforced"),
    ],
    pipes: [ (3, 1, 4), (3, 2, 4), (3, 3, 4) ],
    air_presets: {
        "hot_chlorine": (gases: [("cl2", 250.0)], temperature_k: 1000.0),
        "standard_air": (gases: [("o2", 8.73), ("n2", 32.84)], temperature_k: 293.15),
    },
    air: [
        (1, 1, "hot_chlorine"), (2, 1, "hot_chlorine"), (3, 1, "hot_chlorine"),
        (1, 2, "hot_chlorine"), (2, 2, "hot_chlorine"), (3, 2, "hot_chlorine"),
        (1, 3, "hot_chlorine"), (2, 3, "hot_chlorine"), (3, 3, "hot_chlorine"),
    ],
)]==])
check("neighbour-first")

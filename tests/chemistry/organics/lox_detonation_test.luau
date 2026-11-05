local ignition_room = require("@helpers/ignition_room")
local ui_controls = require("@helpers/ui_controls")

-- LIQUID OXYGEN IN LIQUID METHANE, AND A SPARK: A BLAST.
--
-- A sealed three-tile room at 94 K. The middle tile holds a pool of
-- liquid oxygen and liquid methane; every tile's air is the pool's own
-- saturated headspace, so nothing boils off before the spark. The player
-- stands beside the pool and clicks it with a struck burner.
--
-- * The pool's onset is `lox_detonation`
--   (content/reactions/organics/lox_detonation.luau), not a slow fire.
-- * The onset is a blast (content/main.luau, lib/blast.luau): the room
--   hears the explosion and the player beside it takes the ring's wound.
-- * The liquid methane is gone in the one pass.
local POOL_X, POOL_Y = 2, 1
local T_K = 94.0
local R = 8.314
local CELL_M3 = 3.0
local LOX_MOL = 300.0
local METHANE_LIQUID_MOL = 100.0
-- Saturation pressures at 94 K, from the `o2` and `methane` substance
-- files' curves: about 146 kPa and 17 kPa. Raoult's law gives each
-- liquid's partial pressure over the mixed pool.
local O2_SAT_KPA = 146.0
local METHANE_SAT_KPA = 17.0
local POOL_MOL = LOX_MOL + METHANE_LIQUID_MOL
local MOL_PER_KPA = 1000 * CELL_M3 / (R * T_K)
local O2_GAS_MOL = (LOX_MOL / POOL_MOL) * O2_SAT_KPA * MOL_PER_KPA
local METHANE_GAS_MOL = (METHANE_LIQUID_MOL / POOL_MOL) * METHANE_SAT_KPA * MOL_PER_KPA
-- lib/blast.luau's ring: 15 brute to every body beside the blast tile.
local RING_BRUTE = 15

local headspace =
    string.format('("o2:gas", %.4f), ("methane:gas", %.4f)', O2_GAS_MOL, METHANE_GAS_MOL)
local pool =
    string.format('("o2:liquid", %.4f), ("methane:liquid", %.4f), ', LOX_MOL, METHANE_LIQUID_MOL)

t.world(
    string.format(
        [==[(
    name: "lox pool",
    environment: (kind: Exact(space), gravity_m_s2: Exact(9.80665)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    levels: [
        (
            rows: ["#####", "#...#", "#####"],
            structures: [(1, 1, "player_spawn")],
            items: [(2, 1, "burner")],
            painted: [(1, 1, "headspace"), (2, 1, "pool"), (3, 1, "headspace")],
        ),
    ],
    blends: {
        "headspace": (rows: [%s], temperature_k: %.2f, amount: total),
        "pool": (rows: [%s%s], temperature_k: %.2f, amount: total),
    },
)]==],
        headspace,
        T_K,
        pool,
        headspace,
        T_K
    ),
    0
)
t.set_environment({ sink_k = 2.7, insolation = 0 })
t.set_breathing(false)
local p = t.join()
t.tick()

local function liquid_l(x: number, y: number, key: string): number
    local held = t.room_liquid(x, y)
    return (held and held[key]) or 0.0
end

local function rows_for(rule: string): { SpecLedgerRow }
    local found = {}
    for _, row in ipairs(t.ledger_rows("IgnitionAt")) do
        local fields: any = row
        if string.find(fields.rule, rule, 1, true) ~= nil then
            table.insert(found, row)
        end
    end
    return found
end

local function heard(want: string): boolean
    for _, got in ipairs(t.sounds(p)) do
        if got == want then
            return true
        end
    end
    return false
end

assert(liquid_l(POOL_X, POOL_Y, "o2") > 0, "the pool holds liquid oxygen")
assert(liquid_l(POOL_X, POOL_Y, "methane") > 0, "and liquid methane")
assert(#t.ledger_rows("IgnitionAt") == 0, "nothing burns before the spark")

ignition_room.take_lit_burner(p, POOL_X, POOL_Y)
ignition_room.touch(p, POOL_X, POOL_Y)
local blew = ignition_room.run_until(5, 0.1, function()
    return #rows_for("lox_detonation") > 0
end)
assert(blew ~= nil, "the spark set the pool off as a detonation")
local onset = ignition_room.tile_of(rows_for("lox_detonation")[1])
assert(onset.x == POOL_X and onset.y == POOL_Y, "on the pool's own tile")
t.run_seconds(1)

assert(heard("explosion"), "the room hears the blast")
local brute = ui_controls.number(t.health(p).brute)
assert(
    brute >= RING_BRUTE,
    ("the player beside the pool takes the ring's wound: %g brute"):format(brute)
)
assert(liquid_l(POOL_X, POOL_Y, "methane") < 1e-3, "the liquid methane went in the one pass")
